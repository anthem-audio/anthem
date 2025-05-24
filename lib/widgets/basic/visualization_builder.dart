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

import 'dart:async';

import 'package:anthem/model/project.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Builder that rebuilds when the given visualization data item changes.
///
/// This builder will attempt to rebuild on every frame, but will only
/// actually rebuild if the data item has changed.
class VisualizationBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, double value) builder;
  final VisualizationSubscriptionConfig config;
  final Duration? minimumUpdateInterval;

  const VisualizationBuilder({
    super.key,
    required this.config,
    required this.builder,
    this.minimumUpdateInterval,
  });

  @override
  State<VisualizationBuilder> createState() => _VisualizationBuilderState();
}

class _VisualizationBuilderState extends State<VisualizationBuilder> {
  late final VisualizationSubscription _subscription;
  double _latestValue = 0;
  StreamSubscription<void>? _updateSubscription;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
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

      final newValue = _subscription.readValue();

      if (newValue != _latestValue) {
        setState(() {
          _latestValue = newValue;
        });
      }
    });
  }

  @override
  void didUpdateWidget(VisualizationBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.config != widget.config) {
      _subscription.dispose();
      _subscription = Provider.of<ProjectModel>(
        context,
        listen: false,
      ).visualizationProvider.subscribe(widget.config);
    }
  }

  @override
  void dispose() {
    _subscription.dispose();
    _updateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _latestValue);
  }
}

/// Builder that rebuilds when the given visualization data items change.
///
/// This builder will attempt to rebuild on every frame, but will only
/// actually rebuild if at least one of the data items have changed.
class MultiVisualizationBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, List<double> values) builder;
  final List<VisualizationSubscriptionConfig> configs;
  final Duration? minimumUpdateInterval;

  const MultiVisualizationBuilder({
    super.key,
    required this.configs,
    required this.builder,
    this.minimumUpdateInterval,
  });

  @override
  State<MultiVisualizationBuilder> createState() =>
      _MultiVisualizationBuilderState();
}

class _MultiVisualizationBuilderState extends State<MultiVisualizationBuilder> {
  late final List<VisualizationSubscription> _subscriptions;
  List<double> _latestValues = [];
  List<DateTime?> _lastUpdateTimes = [];

  void _attachSubscriptions() {
    _latestValues = List.filled(widget.configs.length, 0.0);

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

        final newValue = sub.readValue();

        if (newValue != _latestValues[i]) {
          setState(() {
            _latestValues[i] = newValue;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _attachSubscriptions();
  }

  @override
  void didUpdateWidget(MultiVisualizationBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.configs.length != widget.configs.length ||
        !oldWidget.configs.every((config) => widget.configs.contains(config))) {
      for (var sub in _subscriptions) {
        sub.dispose();
      }
      _attachSubscriptions();
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _latestValues);
  }
}
