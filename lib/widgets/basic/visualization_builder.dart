/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

typedef DoubleVisualizationValue = double;
typedef IntVisualizationValue = int;
typedef StringVisualizationValue = String;

typedef VisualizationBuilderCallback<T> =
    Widget Function(BuildContext context, T? value, Duration? engineTime);
typedef MultiVisualizationBuilderCallback<T> =
    Widget Function(
      BuildContext context,
      List<T> values,
      List<Duration?> engineTimes,
    );

typedef DoubleVisualizationBuilder =
    VisualizationBuilderCallback<DoubleVisualizationValue>;
typedef IntVisualizationBuilder =
    VisualizationBuilderCallback<IntVisualizationValue>;
typedef StringVisualizationBuilder =
    VisualizationBuilderCallback<StringVisualizationValue>;
typedef MultiDoubleVisualizationBuilder =
    MultiVisualizationBuilderCallback<DoubleVisualizationValue>;
typedef MultiIntVisualizationBuilder =
    MultiVisualizationBuilderCallback<IntVisualizationValue>;
typedef MultiStringVisualizationBuilder =
    MultiVisualizationBuilderCallback<StringVisualizationValue>;

/// Builder that rebuilds when the given visualization data item changes.
///
/// This builder will attempt to rebuild on every frame, but will only
/// actually rebuild if the data item value or engine time has changed.
abstract final class VisualizationBuilder {
  static Widget double({
    Key? key,
    required VisualizationSubscriptionConfig<DoubleVisualizationValue> config,
    required DoubleVisualizationBuilder builder,
    Duration? minimumUpdateInterval,
  }) {
    return _VisualizationBuilder<DoubleVisualizationValue>(
      key: key,
      config: config,
      builder: builder,
      minimumUpdateInterval: minimumUpdateInterval,
    );
  }

  static Widget int({
    Key? key,
    required VisualizationSubscriptionConfig<IntVisualizationValue> config,
    required IntVisualizationBuilder builder,
    Duration? minimumUpdateInterval,
  }) {
    return _VisualizationBuilder<IntVisualizationValue>(
      key: key,
      config: config,
      builder: builder,
      minimumUpdateInterval: minimumUpdateInterval,
    );
  }

  static Widget string({
    Key? key,
    required VisualizationSubscriptionConfig<StringVisualizationValue> config,
    required StringVisualizationBuilder builder,
    Duration? minimumUpdateInterval,
  }) {
    return _VisualizationBuilder<StringVisualizationValue>(
      key: key,
      config: config,
      builder: builder,
      minimumUpdateInterval: minimumUpdateInterval,
    );
  }
}

class _VisualizationBuilder<T> extends StatefulWidget {
  final VisualizationSubscriptionConfig<T> config;
  final VisualizationBuilderCallback<T> builder;
  final Duration? minimumUpdateInterval;

  const _VisualizationBuilder({
    super.key,
    required this.config,
    required this.builder,
    this.minimumUpdateInterval,
  });

  @override
  State<_VisualizationBuilder<T>> createState() =>
      _VisualizationBuilderState<T>();
}

class _VisualizationBuilderState<T> extends State<_VisualizationBuilder<T>> {
  late VisualizationSubscription<T> _subscription;
  T? _latestValue;
  Duration? _latestEngineTime;
  StreamSubscription<void>? _updateSubscription;
  DateTime? _lastUpdateTime;

  void _resetLatestValues() {
    _latestValue = null;
    _latestEngineTime = null;
    _lastUpdateTime = null;
  }

  bool _shouldSkipUpdate() {
    if (widget.minimumUpdateInterval == null) {
      return false;
    }

    final now = DateTime.now();
    if (_lastUpdateTime != null &&
        now.difference(_lastUpdateTime!) < widget.minimumUpdateInterval!) {
      return true;
    }

    _lastUpdateTime = now;
    return false;
  }

  void _attachSubscription() {
    _subscription = Provider.of<ProjectModel>(
      context,
      listen: false,
    ).visualizationProvider.subscribe(widget.config);

    _updateSubscription = _subscription.onUpdate.listen((_) {
      if (_shouldSkipUpdate()) {
        return;
      }

      final timedValue = _subscription.readTimedValue();
      final newValue = timedValue?.value ?? _subscription.readValue();
      final newEngineTime = timedValue?.engineTime;

      if (newValue != _latestValue || newEngineTime != _latestEngineTime) {
        setState(() {
          _latestValue = newValue;
          _latestEngineTime = newEngineTime;
        });
      }
    });
  }

  void _detachSubscription() {
    _updateSubscription?.cancel();
    _updateSubscription = null;
    _subscription.dispose();
  }

  @override
  void initState() {
    super.initState();
    _attachSubscription();
  }

  @override
  void didUpdateWidget(covariant _VisualizationBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.config != widget.config) {
      _detachSubscription();
      _resetLatestValues();
      _attachSubscription();
    }
  }

  @override
  void dispose() {
    _detachSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _latestValue, _latestEngineTime);
  }
}

/// Builder that rebuilds when the given visualization data items change.
///
/// This builder will attempt to rebuild on every frame, but will only
/// actually rebuild if at least one of the data item values or engine times
/// have changed.
abstract final class MultiVisualizationBuilder {
  static Widget double({
    Key? key,
    required List<VisualizationSubscriptionConfig<DoubleVisualizationValue>>
    configs,
    required MultiDoubleVisualizationBuilder builder,
    Duration? minimumUpdateInterval,
  }) {
    return _MultiVisualizationBuilder<DoubleVisualizationValue>(
      key: key,
      configs: configs,
      builder: builder,
      minimumUpdateInterval: minimumUpdateInterval,
    );
  }

  static Widget int({
    Key? key,
    required List<VisualizationSubscriptionConfig<IntVisualizationValue>>
    configs,
    required MultiIntVisualizationBuilder builder,
    Duration? minimumUpdateInterval,
  }) {
    return _MultiVisualizationBuilder<IntVisualizationValue>(
      key: key,
      configs: configs,
      builder: builder,
      minimumUpdateInterval: minimumUpdateInterval,
    );
  }

  static Widget string({
    Key? key,
    required List<VisualizationSubscriptionConfig<StringVisualizationValue>>
    configs,
    required MultiStringVisualizationBuilder builder,
    Duration? minimumUpdateInterval,
  }) {
    return _MultiVisualizationBuilder<StringVisualizationValue>(
      key: key,
      configs: configs,
      builder: builder,
      minimumUpdateInterval: minimumUpdateInterval,
    );
  }
}

class _MultiVisualizationBuilder<T> extends StatefulWidget {
  final List<VisualizationSubscriptionConfig<T>> configs;
  final MultiVisualizationBuilderCallback<T> builder;
  final Duration? minimumUpdateInterval;

  const _MultiVisualizationBuilder({
    super.key,
    required this.configs,
    required this.builder,
    this.minimumUpdateInterval,
  });

  @override
  State<_MultiVisualizationBuilder<T>> createState() =>
      _MultiVisualizationBuilderState<T>();
}

class _MultiVisualizationBuilderState<T>
    extends State<_MultiVisualizationBuilder<T>> {
  List<VisualizationSubscription<T>> _subscriptions = [];
  final List<StreamSubscription<void>> _updateSubscriptions = [];
  List<T> _latestValues = [];
  List<Duration?> _latestEngineTimes = [];
  List<DateTime?> _lastUpdateTimes = [];

  bool _shouldSkipUpdate(int index) {
    if (widget.minimumUpdateInterval == null) {
      return false;
    }

    final now = DateTime.now();
    if (_lastUpdateTimes[index] != null &&
        now.difference(_lastUpdateTimes[index]!) <
            widget.minimumUpdateInterval!) {
      return true;
    }

    _lastUpdateTimes[index] = now;
    return false;
  }

  void _attachSubscriptions() {
    _latestValues = List<T>.generate(
      widget.configs.length,
      (index) => widget.configs[index].visualizationType.defaultValue,
      growable: false,
    );
    _latestEngineTimes = List.filled(
      widget.configs.length,
      null,
      growable: false,
    );
    _lastUpdateTimes = List.filled(widget.configs.length, null);

    _subscriptions = widget.configs
        .map(
          (config) => Provider.of<ProjectModel>(
            context,
            listen: false,
          ).visualizationProvider.subscribe(config),
        )
        .toList(growable: false);

    for (var i = 0; i < _subscriptions.length; i++) {
      final sub = _subscriptions[i];
      _updateSubscriptions.add(
        sub.onUpdate.listen((_) {
          if (_shouldSkipUpdate(i)) {
            return;
          }

          final timedValue = sub.readTimedValue();
          final newValue = timedValue?.value ?? sub.readValue();
          final newEngineTime = timedValue?.engineTime;

          if (newValue != _latestValues[i] ||
              newEngineTime != _latestEngineTimes[i]) {
            setState(() {
              _latestValues[i] = newValue;
              _latestEngineTimes[i] = newEngineTime;
            });
          }
        }),
      );
    }
  }

  void _detachSubscriptions() {
    for (final updateSubscription in _updateSubscriptions) {
      updateSubscription.cancel();
    }
    _updateSubscriptions.clear();

    for (final sub in _subscriptions) {
      sub.dispose();
    }
    _subscriptions = [];
  }

  bool _didConfigsChange(covariant _MultiVisualizationBuilder<T> oldWidget) {
    if (oldWidget.configs.length != widget.configs.length) {
      return true;
    }

    for (var i = 0; i < widget.configs.length; i++) {
      if (oldWidget.configs[i] != widget.configs[i]) {
        return true;
      }
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _attachSubscriptions();
  }

  @override
  void didUpdateWidget(covariant _MultiVisualizationBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_didConfigsChange(oldWidget)) {
      _detachSubscriptions();
      _attachSubscriptions();
    }
  }

  @override
  void dispose() {
    _detachSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _latestValues, _latestEngineTimes);
  }
}
