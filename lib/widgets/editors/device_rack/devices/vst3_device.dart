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

import 'dart:math' as math;

import 'package:anthem/helpers/parameter_display.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/processors/vst3_processor.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/basic/text_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

const _deviceWidth = 240.0;
const _horizontalPadding = 8.0;
const _verticalPadding = 8.0;
const _controlHeight = 24.0;
const _parameterRowHeight = 30.0;
const _parameterScrollbarWidth = 17.0;
const _knobSize = 22.0;

class Vst3Device extends StatefulWidget {
  final DeviceModel device;

  const Vst3Device({super.key, required this.device});

  @override
  State<Vst3Device> createState() => _Vst3DeviceState();
}

class _Vst3DeviceState extends State<Vst3Device> {
  late final TextEditingController _searchController;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context, listen: false);
    final nodeId = widget.device.nodeIds.single;
    final node = project.processingGraph.nodes[nodeId];

    if (node == null || node.processor is! VST3ProcessorModel) {
      return _InvalidVst3Device(name: widget.device.name);
    }

    return SizedBox(
      width: _deviceWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopRow(node: node, searchController: _searchController),
            const SizedBox(height: 6),
            _RecentParameterSlot(node: node),
            const SizedBox(height: 6),
            Expanded(
              child: _ParameterList(node: node, searchQuery: _searchQuery),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSearchChanged() {
    final nextSearchQuery = _searchController.text.trim().toLowerCase();

    if (nextSearchQuery == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = nextSearchQuery;
    });
  }
}

class _TopRow extends StatelessWidget {
  final NodeModel node;
  final TextEditingController searchController;

  const _TopRow({required this.node, required this.searchController});

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context, listen: false);

    return Row(
      spacing: 6,
      children: [
        Expanded(
          child: TextBox(controller: searchController, height: _controlHeight),
        ),
        Button(
          icon: Icons.openPluginWindow,
          width: _controlHeight,
          height: _controlHeight,
          contentPadding: const EdgeInsets.all(5),
          onPress: () {
            project.engine.processingGraphApi.openPluginWindow(node.id);
          },
        ),
      ],
    );
  }
}

class _RecentParameterSlot extends StatelessWidget {
  final NodeModel node;

  const _RecentParameterSlot({required this.node});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final port = _findParameterPortById(
          node,
          node.lastChangedControlPortId,
        );

        if (port == null) {
          return const _ParameterRowFrame(child: SizedBox.shrink());
        }

        return _Vst3ParameterRow(node: node, port: port);
      },
    );
  }
}

class _ParameterList extends StatefulWidget {
  final NodeModel node;
  final String searchQuery;

  const _ParameterList({required this.node, required this.searchQuery});

  @override
  State<_ParameterList> createState() => _ParameterListState();
}

class _ParameterListState extends State<_ParameterList> {
  late final ScrollController _scrollController;

  double _viewportHeight = 0;
  double _maxScrollExtent = 0;
  bool _metricsSyncScheduled = false;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMetricsSync();

    return Observer(
      builder: (context) {
        final parameterPorts =
            widget.node.controlInputPorts
                .where((port) => port.config.parameterConfig != null)
                .toList()
              ..sort((a, b) => a.id.compareTo(b.id));

        if (parameterPorts.isEmpty) {
          return Center(
            child: Text(
              'No parameters',
              style: TextStyle(color: AnthemTheme.text.disabled, fontSize: 11),
            ),
          );
        }

        final filteredParameterPorts = widget.searchQuery.isEmpty
            ? parameterPorts
            : parameterPorts.where((port) {
                final name = port.config.name ?? 'Parameter ${port.id}';
                return name.toLowerCase().contains(widget.searchQuery);
              }).toList();

        if (filteredParameterPorts.isEmpty) {
          return Center(
            child: Text(
              'No matching parameters',
              style: TextStyle(color: AnthemTheme.text.disabled, fontSize: 11),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  _updateMetrics(notification.metrics);
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemExtent: _parameterRowHeight,
                  itemCount: filteredParameterPorts.length,
                  itemBuilder: (context, index) {
                    return _Vst3ParameterRow(
                      node: widget.node,
                      port: filteredParameterPorts[index],
                    );
                  },
                ),
              ),
            ),
            _ParameterListScrollbar(
              scrollController: _scrollController,
              viewportHeight: _viewportHeight,
              maxScrollExtent: _maxScrollExtent,
            ),
          ],
        );
      },
    );
  }

  void _scheduleMetricsSync() {
    if (_metricsSyncScheduled) return;

    _metricsSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsSyncScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;

      final position = _scrollController.position;
      _updateMetrics(position);

      final maxScrollExtent = math.max(0.0, position.maxScrollExtent);
      final clampedOffset = position.pixels
          .clamp(position.minScrollExtent, maxScrollExtent)
          .toDouble();

      if (clampedOffset != position.pixels) {
        _scrollController.jumpTo(clampedOffset);
      }
    });
  }

  void _updateMetrics(ScrollMetrics metrics) {
    if (axisDirectionToAxis(metrics.axisDirection) != Axis.vertical) {
      return;
    }

    final nextViewportHeight = metrics.viewportDimension.isFinite
        ? math.max(0.0, metrics.viewportDimension)
        : 0.0;
    final nextMaxScrollExtent = metrics.maxScrollExtent.isFinite
        ? math.max(0.0, metrics.maxScrollExtent)
        : 0.0;

    if (nextViewportHeight == _viewportHeight &&
        nextMaxScrollExtent == _maxScrollExtent) {
      return;
    }

    setState(() {
      _viewportHeight = nextViewportHeight;
      _maxScrollExtent = nextMaxScrollExtent;
    });
  }
}

class _ParameterListScrollbar extends StatelessWidget {
  final ScrollController scrollController;
  final double viewportHeight;
  final double maxScrollExtent;

  const _ParameterListScrollbar({
    required this.scrollController,
    required this.viewportHeight,
    required this.maxScrollExtent,
  });

  @override
  Widget build(BuildContext context) {
    final scrollRegionEnd = viewportHeight + maxScrollExtent;

    return Container(
      width: _parameterScrollbarWidth,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AnthemTheme.panel.border)),
      ),
      child: AnimatedBuilder(
        animation: scrollController,
        builder: (context, child) {
          final scrollOffset = scrollController.hasClients
              ? scrollController.offset.clamp(0.0, maxScrollExtent).toDouble()
              : 0.0;

          return ScrollbarRenderer(
            scrollRegionStart: 0,
            scrollRegionEnd: scrollRegionEnd,
            handleStart: scrollOffset,
            handleEnd: scrollOffset + viewportHeight,
            onChange: (event) {
              if (!scrollController.hasClients) {
                return;
              }

              scrollController.jumpTo(
                event.handleStart.clamp(0.0, maxScrollExtent).toDouble(),
              );
            },
          );
        },
      ),
    );
  }
}

class _Vst3ParameterRow extends StatelessWidget {
  final NodeModel node;
  final NodePortModel port;

  const _Vst3ParameterRow({required this.node, required this.port});

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context, listen: false);
    final name = port.config.name ?? 'Parameter ${port.id}';

    return _ParameterRowFrame(
      child: Observer(
        builder: (context) {
          final value = port.parameterValue ?? _defaultValueForPort(port);

          return Row(
            children: [
              SizedBox(
                width: 34,
                child: Center(
                  child: Knob(
                    value: value,
                    width: _knobSize,
                    height: _knobSize,
                    hoverHintOverride: (_) =>
                        _formatParameterHint(name, port, value),
                    hint: (value) => _formatParameterHint(name, port, value),
                    onValueChanged: (newValue) {
                      final value = newValue.clamp(0.0, 1.0).toDouble();
                      port.parameterValue = value;
                      node.lastChangedControlPortId = port.id;
                      project.engine.processingGraphApi.setPluginParameterValue(
                        node.id,
                        port.id,
                        value,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AnthemTheme.text.main,
                        fontSize: 11,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatParameterDisplayValue(port, value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AnthemTheme.text.disabled,
                        fontSize: 10,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ParameterRowFrame extends StatelessWidget {
  final Widget child;

  const _ParameterRowFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _parameterRowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AnthemTheme.panel.border.withValues(alpha: 0.75),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _InvalidVst3Device extends StatelessWidget {
  final String name;

  const _InvalidVst3Device({required this.name});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _deviceWidth,
      child: Center(
        child: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
      ),
    );
  }
}

double _defaultValueForPort(NodePortModel port) {
  return port.config.parameterConfig?.defaultValue ?? 0;
}

NodePortModel? _findParameterPortById(NodeModel node, int? portId) {
  if (portId == null) {
    return null;
  }

  for (final port in node.controlInputPorts) {
    if (port.id == portId && port.config.parameterConfig != null) {
      return port;
    }
  }

  return null;
}

String _formatParameterHint(String name, NodePortModel port, double value) {
  return '$name: ${formatParameterDisplayValue(port, value)}';
}
