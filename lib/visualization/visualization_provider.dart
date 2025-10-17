/*
  Copyright (C) 2025 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

part of 'visualization.dart';

/// Allows the UI to subscribe to visualization items and receive updates for
/// them.
class VisualizationProvider {
  final ProjectModel _project;
  late final StreamSubscription<EngineState> _engineStateChangeSub;

  final Map<String, List<VisualizationSubscription>> _subscriptions = {};

  bool _enabled = true;

  VisualizationProvider(this._project) {
    if (_project.engine.engineState == EngineState.running) {
      _sendUpdateIntervalToEngine();
    }

    _engineStateChangeSub = _project.engine.engineStateStream.listen((state) {
      if (state == EngineState.running) {
        _sendUpdateIntervalToEngine();
        _scheduleSubscriptionListUpdate();
      }

      // If the engine isn't running, the visualization subscriptions shouldn't
      // check for updates.
      if (state == EngineState.stopped || state == EngineState.running) {
        for (var subscriptions in _subscriptions.values) {
          for (final subscription in subscriptions) {
            if (state == EngineState.stopped) {
              subscription._engineStopped();
            } else {
              subscription._engineStarted();
            }
          }
        }
      }
    });
  }

  void _sendUpdateIntervalToEngine() {
    final refreshRate = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .display
        .refreshRate;

    _project.engine.visualizationApi.setUpdateInterval(
      (1000 / refreshRate) * 0.9, // A bit faster than the refresh rate
    );
  }

  void processVisualizationUpdate(VisualizationUpdateEvent update) {
    for (final item in update.items) {
      final subscriptions = _subscriptions[item.id];

      if (subscriptions != null) {
        for (final subscription in subscriptions) {
          final values = item.values as List;

          for (final value in values) {
            switch (value) {
              case String _:
                subscription._addValue(value);
              case double _:
              case int _:
                subscription._addValue(value.toDouble());
              default:
                throw ArgumentError(
                  'Unexpected value type: ${value.runtimeType} for item ${item.id}. Expected String or double.',
                );
            }
          }
        }
      }
    }
  }

  VisualizationSubscription subscribe(VisualizationSubscriptionConfig config) {
    final subscription = VisualizationSubscription(config, this);

    if (_subscriptions[config.id] == null) {
      _subscriptions[config.id] = [];
      _scheduleSubscriptionListUpdate();
    }

    _subscriptions[config.id]!.add(subscription);

    return subscription;
  }

  void _unsubscribe(VisualizationSubscription subscription) {
    final subscriptions = _subscriptions[subscription._config.id];

    if (subscriptions != null) {
      subscriptions.remove(subscription);

      if (subscriptions.isEmpty) {
        _subscriptions.remove(subscription._config.id);

        _scheduleSubscriptionListUpdate();
      }
    }
  }

  bool _isSubscriptionListUpdatePending = false;

  /// Sets whether the visualization provider is enabled.
  ///
  /// This is meant to be used when switching between tabs. If a tab is not on
  /// screen, then we don't need to be streaming visualization data for it.
  void setEnabled(bool enabled) {
    if (_enabled == enabled) {
      return;
    }

    _enabled = enabled;
    _scheduleSubscriptionListUpdate();
  }

  /// Schedules an update to the subscription list in the engine.
  ///
  /// This allows many updates to happen to the subscription list while
  /// generating only one update.
  void _scheduleSubscriptionListUpdate() {
    if (_isSubscriptionListUpdatePending) {
      return;
    }

    _isSubscriptionListUpdatePending = true;

    scheduleMicrotask(() async {
      // If the engine is starting or stopped, wait for it to be ready.
      await _project.engine.readyForMessages;

      _project.engine.visualizationApi.setSubscriptions(
        _enabled ? _subscriptions.keys.toList() : [],
      );
      _isSubscriptionListUpdatePending = false;
    });
  }

  /// Overrides the value for a specific visualization item for a certain
  /// duration.
  ///
  /// If an action in the UI triggers a UI update, it usually renders in the
  /// next frame. However, if the UI is dependent on a visualization value for
  /// an update, then the update usually occurs at least a frame later. If a
  /// given action in the UI contains both types of updates, then there can be a
  /// visible desync between the two updates.
  ///
  /// This method can be used to override a visualization value with the
  /// expected update value before the engine can send the update, which can
  /// prevent this desync.
  void overrideValue({
    required String id,
    double? doubleValue,
    String? stringValue,
    required Duration duration,
  }) {
    final subscriptions =
        _subscriptions[id] ?? Iterable<VisualizationSubscription>.empty();
    for (final sub in subscriptions) {
      sub.setOverride(
        valueDouble: doubleValue,
        valueString: stringValue,
        duration: duration,
      );
    }
  }

  void dispose() {
    _engineStateChangeSub.cancel();

    while (_subscriptions.isNotEmpty) {
      final groupKey = _subscriptions.keys.first;
      final group = _subscriptions[groupKey]!;
      var groupLength = group.length;
      while (groupLength != 0) {
        final subscription = group.last;

        // This should cause the subscription to be removed from the list.
        subscription.dispose();

        groupLength--;
        if (group.length != groupLength) {
          // Prevents an infinite loop if the list length doesn't change due to
          // future bugs here or in VisualizationSubscription.dispose().
          throw StateError(
            'Subscription list length mismatch when disposing VisualizationProvider.',
          );
        }
      }
      _subscriptions.remove(groupKey);
    }

    _subscriptions.clear();
  }
}
