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
  late final VisualizationSubscriptionController<T> _controller;

  @override
  void initState() {
    super.initState();

    _controller = VisualizationSubscriptionController<T>(
      visualizationProvider: Provider.of<ProjectModel>(
        context,
        listen: false,
      ).visualizationProvider,
      config: widget.config,
      minimumUpdateInterval: widget.minimumUpdateInterval,
    );
  }

  @override
  void didUpdateWidget(covariant _VisualizationBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    _controller.update(
      config: widget.config,
      minimumUpdateInterval: widget.minimumUpdateInterval,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return widget.builder(
          context,
          _controller.value,
          _controller.engineTime,
        );
      },
    );
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
  late final MultiVisualizationSubscriptionController<T> _controller;

  @override
  void initState() {
    super.initState();

    _controller = MultiVisualizationSubscriptionController<T>(
      visualizationProvider: Provider.of<ProjectModel>(
        context,
        listen: false,
      ).visualizationProvider,
      configs: widget.configs,
      minimumUpdateInterval: widget.minimumUpdateInterval,
    );
  }

  @override
  void didUpdateWidget(covariant _MultiVisualizationBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    _controller.update(
      configs: widget.configs,
      minimumUpdateInterval: widget.minimumUpdateInterval,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return widget.builder(
          context,
          _controller.values,
          _controller.engineTimes,
        );
      },
    );
  }
}
