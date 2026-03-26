/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:async';
import 'dart:collection';

import 'package:anthem/visualization/visualization.dart';
import 'package:flutter/foundation.dart';

/// Listenable controller that owns a subscription to a visualization value.
///
/// This is the primary connection point for Flutter to interact with the
/// visualization system. It takes a visualization config, uses that config to
/// subscribe to the indicated value, and then calls notifyListeners() whenever
/// the subscribed value is updated.
class VisualizationSubscriptionController<T> extends ChangeNotifier {
  final VisualizationProvider _visualizationProvider;

  VisualizationSubscriptionConfig<T> _config;
  Duration? _minimumUpdateInterval;

  VisualizationSubscription<T>? _subscription;
  StreamSubscription<void>? _updateSubscription;

  T? _value;
  Duration? _engineTime;
  Duration? _lastUpdateWallTime;

  /// Creates a controller for a single visualization subscription.
  ///
  /// The controller subscribes immediately and begins caching the latest
  /// rendered value exposed by the underlying [VisualizationSubscription].
  VisualizationSubscriptionController({
    required VisualizationProvider visualizationProvider,
    required VisualizationSubscriptionConfig<T> config,
    Duration? minimumUpdateInterval,
  }) : _visualizationProvider = visualizationProvider,
       _config = config,
       _minimumUpdateInterval = minimumUpdateInterval {
    _attachSubscription();
  }

  /// The current subscription config for this controller.
  VisualizationSubscriptionConfig<T> get config => _config;

  /// The minimum wall-clock interval between emitted controller updates.
  ///
  /// When this is non-null, incoming subscription ticks that arrive more
  /// frequently than this are ignored.
  Duration? get minimumUpdateInterval => _minimumUpdateInterval;

  /// The latest cached visualization value.
  ///
  /// This is `null` until the controller has received an update with a value,
  /// or until the underlying subscription emits its first default-backed value.
  T? get value => _value;

  /// The engine time associated with the latest cached value.
  ///
  /// This is `null` until the underlying subscription exposes a timed value.
  Duration? get engineTime => _engineTime;

  /// Updates the controller configuration.
  ///
  /// If [config] changes, the controller disposes its current subscription,
  /// clears its cached state, and subscribes again using the new config.
  ///
  /// Changing only [minimumUpdateInterval] updates the throttling behavior in
  /// place without clearing cached data or notifying listeners immediately.
  void update({
    required VisualizationSubscriptionConfig<T> config,
    Duration? minimumUpdateInterval,
  }) {
    final didConfigChange = _config != config;
    _minimumUpdateInterval = minimumUpdateInterval;

    if (!didConfigChange) {
      return;
    }

    final previousValue = _value;
    final previousEngineTime = _engineTime;

    _detachSubscription();
    _config = config;
    _resetCachedState();
    _attachSubscription();

    if (previousValue != _value || previousEngineTime != _engineTime) {
      notifyListeners();
    }
  }

  bool _shouldSkipUpdate() {
    if (_minimumUpdateInterval == null) {
      return false;
    }

    final now = _visualizationProvider.clock.now();
    if (_lastUpdateWallTime != null &&
        now - _lastUpdateWallTime! < _minimumUpdateInterval!) {
      return true;
    }

    _lastUpdateWallTime = now;
    return false;
  }

  void _resetCachedState() {
    _value = null;
    _engineTime = null;
    _lastUpdateWallTime = null;
  }

  void _attachSubscription() {
    final subscription = _visualizationProvider.subscribe(_config);
    _subscription = subscription;

    _updateSubscription = subscription.onUpdate.listen((_) {
      if (_shouldSkipUpdate()) {
        return;
      }

      final timedValue = subscription.readTimedValue();
      final nextValue = timedValue?.value ?? subscription.readValue();
      final nextEngineTime = timedValue?.engineTime;

      if (nextValue == _value && nextEngineTime == _engineTime) {
        return;
      }

      _value = nextValue;
      _engineTime = nextEngineTime;
      notifyListeners();
    });
  }

  void _detachSubscription() {
    _updateSubscription?.cancel();
    _updateSubscription = null;
    _subscription?.dispose();
    _subscription = null;
  }

  @override
  void dispose() {
    _detachSubscription();
    super.dispose();
  }
}

/// Listenable controller that owns a list of subscriptions to visualization
/// values.
///
/// This behaves like [VisualizationSubscriptionController], but caches a fixed
/// ordered set of values and engine times. Each entry is updated independently
/// according to the matching config in [configs].
class MultiVisualizationSubscriptionController<T> extends ChangeNotifier {
  final VisualizationProvider _visualizationProvider;

  List<VisualizationSubscriptionConfig<T>> _configs;
  Duration? _minimumUpdateInterval;

  List<VisualizationSubscription<T>> _subscriptions = [];
  final List<StreamSubscription<void>> _updateSubscriptions = [];

  List<T> _values = [];
  UnmodifiableListView<T> _valuesView = UnmodifiableListView(<T>[]);

  List<Duration?> _engineTimes = [];
  UnmodifiableListView<Duration?> _engineTimesView = UnmodifiableListView(
    const <Duration?>[],
  );

  List<Duration?> _lastUpdateWallTimes = [];

  /// Creates a controller for a fixed list of visualization subscriptions.
  ///
  /// The controller subscribes immediately and initializes [values] with each
  /// config's default value. [engineTimes] starts with `null` entries until
  /// timed values arrive from the underlying subscriptions.
  MultiVisualizationSubscriptionController({
    required VisualizationProvider visualizationProvider,
    required List<VisualizationSubscriptionConfig<T>> configs,
    Duration? minimumUpdateInterval,
  }) : _visualizationProvider = visualizationProvider,
       _configs = List<VisualizationSubscriptionConfig<T>>.of(
         configs,
         growable: false,
       ),
       _minimumUpdateInterval = minimumUpdateInterval {
    _attachSubscriptions();
  }

  /// The ordered list of configs currently owned by this controller.
  List<VisualizationSubscriptionConfig<T>> get configs => _configs;

  /// The minimum wall-clock interval between emitted updates for each entry.
  ///
  /// Throttling is applied independently per index in [values].
  Duration? get minimumUpdateInterval => _minimumUpdateInterval;

  /// The latest cached values for each configured subscription.
  ///
  /// This list always has the same length and ordering as [configs].
  List<T> get values => _valuesView;

  /// The cached engine times for each configured subscription.
  ///
  /// Entries remain `null` until the matching subscription exposes a timed
  /// value.
  List<Duration?> get engineTimes => _engineTimesView;

  /// Updates the controller configuration.
  ///
  /// If [configs] changes in length, order, or contents, the controller
  /// recreates the owned subscriptions and resets its cached state to match the
  /// new configuration.
  ///
  /// Changing only [minimumUpdateInterval] updates the throttling behavior in
  /// place without clearing cached data or notifying listeners immediately.
  void update({
    required List<VisualizationSubscriptionConfig<T>> configs,
    Duration? minimumUpdateInterval,
  }) {
    final nextConfigs = List<VisualizationSubscriptionConfig<T>>.of(
      configs,
      growable: false,
    );
    final didConfigsChange = _didConfigsChange(nextConfigs);
    _minimumUpdateInterval = minimumUpdateInterval;

    if (!didConfigsChange) {
      return;
    }

    final previousValues = _values;
    final previousEngineTimes = _engineTimes;

    _detachSubscriptions();
    _configs = nextConfigs;
    _attachSubscriptions();

    if (!listEquals(previousValues, _values) ||
        !listEquals(previousEngineTimes, _engineTimes)) {
      notifyListeners();
    }
  }

  bool _didConfigsChange(List<VisualizationSubscriptionConfig<T>> nextConfigs) {
    if (_configs.length != nextConfigs.length) {
      return true;
    }

    for (var i = 0; i < nextConfigs.length; i++) {
      if (_configs[i] != nextConfigs[i]) {
        return true;
      }
    }

    return false;
  }

  bool _shouldSkipUpdate(int index) {
    if (_minimumUpdateInterval == null) {
      return false;
    }

    final now = _visualizationProvider.clock.now();
    if (_lastUpdateWallTimes[index] != null &&
        now - _lastUpdateWallTimes[index]! < _minimumUpdateInterval!) {
      return true;
    }

    _lastUpdateWallTimes[index] = now;
    return false;
  }

  void _attachSubscriptions() {
    _values = List<T>.generate(
      _configs.length,
      (index) => _configs[index].visualizationType.defaultValue,
      growable: false,
    );
    _valuesView = UnmodifiableListView<T>(_values);

    _engineTimes = List<Duration?>.filled(
      _configs.length,
      null,
      growable: false,
    );
    _engineTimesView = UnmodifiableListView<Duration?>(_engineTimes);

    _lastUpdateWallTimes = List<Duration?>.filled(
      _configs.length,
      null,
      growable: false,
    );

    _subscriptions = _configs
        .map(_visualizationProvider.subscribe)
        .toList(growable: false);

    for (var i = 0; i < _subscriptions.length; i++) {
      final subscription = _subscriptions[i];

      _updateSubscriptions.add(
        subscription.onUpdate.listen((_) {
          if (_shouldSkipUpdate(i)) {
            return;
          }

          final timedValue = subscription.readTimedValue();
          final nextValue = timedValue?.value ?? subscription.readValue();
          final nextEngineTime = timedValue?.engineTime;

          if (_values[i] == nextValue && _engineTimes[i] == nextEngineTime) {
            return;
          }

          _values[i] = nextValue;
          _engineTimes[i] = nextEngineTime;
          notifyListeners();
        }),
      );
    }
  }

  void _detachSubscriptions() {
    for (final updateSubscription in _updateSubscriptions) {
      updateSubscription.cancel();
    }
    _updateSubscriptions.clear();

    for (final subscription in _subscriptions) {
      subscription.dispose();
    }
    _subscriptions = [];
  }

  @override
  void dispose() {
    _detachSubscriptions();
    super.dispose();
  }
}
