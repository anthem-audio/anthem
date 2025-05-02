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

  const VisualizationBuilder({
    super.key,
    required this.config,
    required this.builder,
  });

  @override
  State<VisualizationBuilder> createState() => _VisualizationBuilderState();
}

class _VisualizationBuilderState extends State<VisualizationBuilder> {
  late final VisualizationSubscription _subscription;
  double _latestValue = 0;
  StreamSubscription<void>? _updateSubscription;

  @override
  void initState() {
    super.initState();
    _subscription = Provider.of<ProjectModel>(
      context,
      listen: false,
    ).visualizationProvider.subscribe(widget.config);

    _updateSubscription = _subscription.onUpdate.listen((_) {
      final newValue = _subscription.readValue();

      if (newValue != _latestValue) {
        setState(() {
          _latestValue = newValue;
        });
      }
    });
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
