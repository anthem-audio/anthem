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

  VisualizationProvider(this._project) {
    if (_project.engine.engineState == EngineState.running) {
      _sendUpdateIntervalToEngine();
    }

    _engineStateChangeSub = _project.engine.engineStateStream.listen((state) {
      if (state == EngineState.running) {
        _sendUpdateIntervalToEngine();
        _scheduleSubscriptionListUpdate();
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

  void processVisualizationUpdate(VisualizationUpdate update) {
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
                subscription._addValue(value);
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

  /// Schedules an update to the subscription list in the engine.
  ///
  /// This allows many updates to happen to the subscription list while
  /// geenrating only one update.
  void _scheduleSubscriptionListUpdate() {
    if (_isSubscriptionListUpdatePending) {
      return;
    }

    _isSubscriptionListUpdatePending = true;

    scheduleMicrotask(() async {
      // If the engine is starting or stopped, wait for it to be ready.
      await _project.engine.readyForMessages;

      _project.engine.visualizationApi.setSubscriptions(
        _subscriptions.keys.toList(),
      );
      _isSubscriptionListUpdatePending = false;
    });
  }

  void dispose() {
    _engineStateChangeSub.cancel();

    for (final subscriptions in _subscriptions.values) {
      for (final subscription in subscriptions) {
        subscription.dispose();
      }
    }

    _subscriptions.clear();
  }
}
