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

typedef DoubleVisualizationBuilder =
    Widget Function(BuildContext context, double? value, Duration? engineTime);
typedef IntVisualizationBuilder =
    Widget Function(BuildContext context, int? value, Duration? engineTime);
typedef StringVisualizationBuilder =
    Widget Function(BuildContext context, String? value, Duration? engineTime);
typedef MultiDoubleVisualizationBuilder =
    Widget Function(
      BuildContext context,
      List<double> values,
      List<Duration?> engineTimes,
    );
typedef MultiIntVisualizationBuilder =
    Widget Function(
      BuildContext context,
      List<int> values,
      List<Duration?> engineTimes,
    );
typedef MultiStringVisualizationBuilder =
    Widget Function(
      BuildContext context,
      List<String> values,
      List<Duration?> engineTimes,
    );

/// Builder that rebuilds when the given visualization data item changes.
///
/// This builder will attempt to rebuild on every frame, but will only
/// actually rebuild if the data item value or engine time has changed.
class VisualizationBuilder extends StatefulWidget {
  final DoubleVisualizationBuilder? doubleBuilder;
  final IntVisualizationBuilder? intBuilder;
  final StringVisualizationBuilder? stringBuilder;
  final VisualizationSubscriptionConfig config;
  final Duration? minimumUpdateInterval;

  /// Creates a builder that expects a double value from the given subscription
  /// config.
  const VisualizationBuilder.double({
    super.key,
    required this.config,
    required DoubleVisualizationBuilder? builder,
    this.minimumUpdateInterval,
  }) : doubleBuilder = builder,
       intBuilder = null,
       stringBuilder = null;

  /// Creates a builder that expects an int value from the given subscription
  /// config.
  const VisualizationBuilder.int({
    super.key,
    required this.config,
    required IntVisualizationBuilder? builder,
    this.minimumUpdateInterval,
  }) : doubleBuilder = null,
       intBuilder = builder,
       stringBuilder = null;

  /// Creates a builder that expects a string value from the given subscription
  /// config.
  const VisualizationBuilder.string({
    super.key,
    required this.config,
    required StringVisualizationBuilder? builder,
    this.minimumUpdateInterval,
  }) : doubleBuilder = null,
       intBuilder = null,
       stringBuilder = builder;

  @override
  State<VisualizationBuilder> createState() => _VisualizationBuilderState();
}

class _VisualizationBuilderState extends State<VisualizationBuilder> {
  late VisualizationSubscription _subscription;
  double? _latestDoubleValue;
  int? _latestIntValue;
  String? _latestStringValue;
  Duration? _latestEngineTime;
  StreamSubscription<void>? _updateSubscription;
  DateTime? _lastUpdateTime;

  void _resetLatestValues() {
    _latestDoubleValue = null;
    _latestIntValue = null;
    _latestStringValue = null;
    _latestEngineTime = null;
    _lastUpdateTime = null;
  }

  void _updateDoubleValue() {
    final timedValue = _subscription.readTimedValue();
    final newValue = timedValue?.value ?? _subscription.readValue();
    final newEngineTime = timedValue?.engineTime;

    if (newValue != _latestDoubleValue || newEngineTime != _latestEngineTime) {
      setState(() {
        _latestDoubleValue = newValue;
        _latestEngineTime = newEngineTime;
      });
    }
  }

  void _updateIntValue() {
    final timedValue = _subscription.readTimedValueInt();
    final newValue = timedValue?.value ?? _subscription.readValueInt();
    final newEngineTime = timedValue?.engineTime;

    if (newValue != _latestIntValue || newEngineTime != _latestEngineTime) {
      setState(() {
        _latestIntValue = newValue;
        _latestEngineTime = newEngineTime;
      });
    }
  }

  void _updateStringValue() {
    final timedValue = _subscription.readTimedValueString();
    final newValue = timedValue?.value ?? _subscription.readValueString();
    final newEngineTime = timedValue?.engineTime;

    if (newValue != _latestStringValue || newEngineTime != _latestEngineTime) {
      setState(() {
        _latestStringValue = newValue;
        _latestEngineTime = newEngineTime;
      });
    }
  }

  void _attachSubscription() {
    _subscription = Provider.of<ProjectModel>(
      context,
      listen: false,
    ).visualizationProvider.subscribe(widget.config);

    _updateSubscription = _subscription.onUpdate.listen((_) {
      if (widget.minimumUpdateInterval != null) {
        final now = DateTime.now();
        if (_lastUpdateTime != null &&
            now.difference(_lastUpdateTime!) < widget.minimumUpdateInterval!) {
          return;
        }
        _lastUpdateTime = now;
      }

      if (widget.doubleBuilder != null) {
        _updateDoubleValue();
      }

      if (widget.intBuilder != null) {
        _updateIntValue();
      }

      if (widget.stringBuilder != null) {
        _updateStringValue();
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
  void didUpdateWidget(VisualizationBuilder oldWidget) {
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
    final doubleWidget = widget.doubleBuilder?.call(
      context,
      _latestDoubleValue,
      _latestEngineTime,
    );
    if (doubleWidget != null) {
      return doubleWidget;
    }

    final intWidget = widget.intBuilder?.call(
      context,
      _latestIntValue,
      _latestEngineTime,
    );
    if (intWidget != null) {
      return intWidget;
    }

    final stringWidget = widget.stringBuilder?.call(
      context,
      _latestStringValue,
      _latestEngineTime,
    );
    return stringWidget!;
  }
}

/// Builder that rebuilds when the given visualization data items change.
///
/// This builder will attempt to rebuild on every frame, but will only
/// actually rebuild if at least one of the data item values or engine times
/// have changed.
class MultiVisualizationBuilder extends StatefulWidget {
  final MultiDoubleVisualizationBuilder? doubleBuilder;
  final MultiIntVisualizationBuilder? intBuilder;
  final MultiStringVisualizationBuilder? stringBuilder;
  final List<VisualizationSubscriptionConfig> configs;
  final Duration? minimumUpdateInterval;

  const MultiVisualizationBuilder.double({
    super.key,
    required this.configs,
    required MultiDoubleVisualizationBuilder? builder,
    this.minimumUpdateInterval,
  }) : doubleBuilder = builder,
       intBuilder = null,
       stringBuilder = null;

  const MultiVisualizationBuilder.int({
    super.key,
    required this.configs,
    required MultiIntVisualizationBuilder? builder,
    this.minimumUpdateInterval,
  }) : doubleBuilder = null,
       intBuilder = builder,
       stringBuilder = null;

  const MultiVisualizationBuilder.string({
    super.key,
    required this.configs,
    required MultiStringVisualizationBuilder? builder,
    this.minimumUpdateInterval,
  }) : doubleBuilder = null,
       intBuilder = null,
       stringBuilder = builder;

  @override
  State<MultiVisualizationBuilder> createState() =>
      _MultiVisualizationBuilderState();
}

class _MultiVisualizationBuilderState extends State<MultiVisualizationBuilder> {
  List<VisualizationSubscription> _subscriptions = [];
  final List<StreamSubscription<void>> _updateSubscriptions = [];
  List<double> _latestDoubleValues = [];
  List<int> _latestIntValues = [];
  List<String> _latestStringValues = [];
  List<Duration?> _latestEngineTimes = [];
  List<DateTime?> _lastUpdateTimes = [];

  void _attachSubscriptions() {
    _latestDoubleValues = List.filled(
      widget.configs.length,
      0.0,
      growable: false,
    );
    _latestStringValues = List.filled(
      widget.configs.length,
      '',
      growable: false,
    );
    _latestIntValues = List.filled(widget.configs.length, 0, growable: false);
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
        .toList();

    for (var i = 0; i < _subscriptions.length; i++) {
      final sub = _subscriptions[i];
      _updateSubscriptions.add(
        sub.onUpdate.listen((_) {
          if (widget.minimumUpdateInterval != null) {
            final now = DateTime.now();
            if (_lastUpdateTimes[i] != null &&
                now.difference(_lastUpdateTimes[i]!) <
                    widget.minimumUpdateInterval!) {
              return;
            }
            _lastUpdateTimes[i] = now;
          }

          if (widget.doubleBuilder != null) {
            final timedValue = sub.readTimedValue();
            final newValue = timedValue?.value ?? sub.readValue();
            final newEngineTime = timedValue?.engineTime;

            if (newValue != _latestDoubleValues[i] ||
                newEngineTime != _latestEngineTimes[i]) {
              setState(() {
                _latestDoubleValues[i] = newValue;
                _latestEngineTimes[i] = newEngineTime;
              });
            }
          }

          if (widget.intBuilder != null) {
            final timedValue = sub.readTimedValueInt();
            final newValue = timedValue?.value ?? sub.readValueInt();
            final newEngineTime = timedValue?.engineTime;

            if (newValue != _latestIntValues[i] ||
                newEngineTime != _latestEngineTimes[i]) {
              setState(() {
                _latestIntValues[i] = newValue;
                _latestEngineTimes[i] = newEngineTime;
              });
            }
          }

          if (widget.stringBuilder != null) {
            final timedValue = sub.readTimedValueString();
            final newValue = timedValue?.value ?? sub.readValueString();
            final newEngineTime = timedValue?.engineTime;

            if (newValue != _latestStringValues[i] ||
                newEngineTime != _latestEngineTimes[i]) {
              setState(() {
                _latestStringValues[i] = newValue;
                _latestEngineTimes[i] = newEngineTime;
              });
            }
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

  bool _didConfigsChange(MultiVisualizationBuilder oldWidget) {
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
  void didUpdateWidget(MultiVisualizationBuilder oldWidget) {
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
    final doubleWidget = widget.doubleBuilder?.call(
      context,
      _latestDoubleValues,
      _latestEngineTimes,
    );
    if (doubleWidget != null) {
      return doubleWidget;
    }

    final intWidget = widget.intBuilder?.call(
      context,
      _latestIntValues,
      _latestEngineTimes,
    );
    if (intWidget != null) {
      return intWidget;
    }

    final stringWidget = widget.stringBuilder?.call(
      context,
      _latestStringValues,
      _latestEngineTimes,
    );
    return stringWidget!;
  }
}
