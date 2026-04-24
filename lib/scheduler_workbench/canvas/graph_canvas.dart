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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../models/processing_graph.dart';
import '../view_model.dart';
import 'graph_painter.dart';
import 'node_title_atlas.dart';

class GraphCanvas extends StatefulWidget {
  final ProcessingGraphModel graph;
  final WorkbenchViewModel viewModel;

  const GraphCanvas({super.key, required this.graph, required this.viewModel});

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas> {
  late final NodeTitleAtlasController titleAtlasController =
      NodeTitleAtlasController();

  @override
  void dispose() {
    titleAtlasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final viewportCenter = viewportSize.center(Offset.zero);

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent) {
                      return;
                    }

                    final scaleFactor = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
                    widget.viewModel.zoomAt(
                      localFocalPoint: event.localPosition,
                      viewportCenter: viewportCenter,
                      scaleFactor: scaleFactor,
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      widget.viewModel.panBy(details.delta);
                    },
                    child: Observer(
                      builder: (context) {
                        final snapshot = _buildSnapshot(
                          widget.graph,
                          widget.viewModel,
                          devicePixelRatio,
                        );

                        titleAtlasController.scheduleUpdate(
                          entries: [
                            for (final node in snapshot.nodes)
                              NodeTitleAtlasEntry(
                                nodeId: node.id,
                                title: node.name,
                              ),
                          ],
                          devicePixelRatio: devicePixelRatio,
                          maxTextWidth: GraphPainter.nodeTitleMaxWidth,
                          maxTextHeight: GraphPainter.nodeTitleMaxHeight,
                        );

                        return AnimatedBuilder(
                          animation: titleAtlasController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: GraphPainter(
                                snapshot: snapshot,
                                titleAtlas: titleAtlasController.snapshot,
                              ),
                              child: child,
                            );
                          },
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 16,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (_) {},
                  child: Observer(
                    builder: (context) {
                      return _ZoomControls(
                        zoom: widget.viewModel.zoom,
                        onChanged: (value) {
                          widget.viewModel.setZoomAtCenter(
                            viewportCenter: viewportCenter,
                            newZoom: value,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

GraphSnapshot _buildSnapshot(
  ProcessingGraphModel graph,
  WorkbenchViewModel viewModel,
  double devicePixelRatio,
) {
  final nodes = graph.nodes.values
      .map(
        (node) => NodeSnapshot(
          id: node.id,
          name: node.name,
          position: Offset(node.x, node.y),
          processingState: node.processingState,
        ),
      )
      .toList(growable: false);

  return GraphSnapshot(
    nodes: nodes,
    connections: graph.connections.values.toList(growable: false),
    zoom: viewModel.zoom,
    viewportOffset: viewModel.viewportOffset,
    devicePixelRatio: devicePixelRatio,
  );
}

class _ZoomControls extends StatelessWidget {
  final double zoom;
  final ValueChanged<double> onChanged;

  const _ZoomControls({required this.zoom, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD151515),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3C3C3C)),
      ),
      child: SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${(zoom * 100).round()}%'),
              Slider(
                value: _zoomToSliderValue(zoom),
                onChanged: (value) {
                  onChanged(_sliderValueToZoom(value));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _zoomToSliderValue(double zoom) {
    final clampedZoom = zoom.clamp(workbenchMinZoom, workbenchMaxZoom);
    final zoomRange = workbenchMaxZoom / workbenchMinZoom;

    return math.log(clampedZoom / workbenchMinZoom) / math.log(zoomRange);
  }

  double _sliderValueToZoom(double value) {
    final zoomRange = workbenchMaxZoom / workbenchMinZoom;

    return workbenchMinZoom * math.pow(zoomRange, value);
  }
}
