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

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/node_connection.dart';
import 'node_title_atlas.dart';

class GraphSnapshot {
  final List<NodeSnapshot> nodes;
  final List<NodeConnectionModel> connections;
  final double zoom;
  final Offset viewportOffset;
  final double devicePixelRatio;

  const GraphSnapshot({
    required this.nodes,
    required this.connections,
    required this.zoom,
    required this.viewportOffset,
    required this.devicePixelRatio,
  });
}

class NodeSnapshot {
  final int id;
  final String name;
  final Offset position;

  const NodeSnapshot({
    required this.id,
    required this.name,
    required this.position,
  });
}

class GraphPainter extends CustomPainter {
  static const nodeSize = Size(168, 78);
  static const nodeTitleMaxWidth = 144.0;
  static const nodeTitleMaxHeight = 40.0;

  final GraphSnapshot snapshot;
  final NodeTitleAtlasSnapshot titleAtlas;

  const GraphPainter({required this.snapshot, required this.titleAtlas});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF111111),
    );

    final origin = size.center(snapshot.viewportOffset);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(snapshot.zoom);

    _drawGrid(canvas, size, origin);

    final nodesById = {for (final node in snapshot.nodes) node.id: node};

    for (final connection in snapshot.connections) {
      final source = nodesById[connection.sourceNodeId];
      final destination = nodesById[connection.destinationNodeId];

      if (source == null || destination == null) {
        continue;
      }

      _drawConnection(canvas, source, destination);
    }

    for (final node in snapshot.nodes) {
      _drawNode(canvas, node);
    }

    _drawNodeTitles(canvas);

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size viewportSize, Offset origin) {
    final zoom = snapshot.zoom;
    final worldLeft = -origin.dx / zoom;
    final worldTop = -origin.dy / zoom;
    final worldRight = (viewportSize.width - origin.dx) / zoom;
    final worldBottom = (viewportSize.height - origin.dy) / zoom;
    const gridSpacing = 80.0;
    final gridPaint = Paint()
      ..color = const Color(0xFF242424)
      ..strokeWidth = 1 / zoom;

    for (
      var x = (worldLeft / gridSpacing).floor() * gridSpacing;
      x <= worldRight;
      x += gridSpacing
    ) {
      canvas.drawLine(Offset(x, worldTop), Offset(x, worldBottom), gridPaint);
    }

    for (
      var y = (worldTop / gridSpacing).floor() * gridSpacing;
      y <= worldBottom;
      y += gridSpacing
    ) {
      canvas.drawLine(Offset(worldLeft, y), Offset(worldRight, y), gridPaint);
    }
  }

  void _drawConnection(
    Canvas canvas,
    NodeSnapshot source,
    NodeSnapshot destination,
  ) {
    final sourceRect = _nodeRect(source);
    final destinationRect = _nodeRect(destination);
    final start = _rectEdgeToward(sourceRect, destinationRect.center);
    final end = _rectEdgeToward(destinationRect, sourceRect.center);
    final vector = end - start;
    final distance = vector.distance;

    if (distance == 0) {
      return;
    }

    final direction = vector / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final arrowLength = 13 / snapshot.zoom;
    final arrowWidth = 8 / snapshot.zoom;
    final lineEnd = end - direction * arrowLength * 0.65;
    final linePaint = Paint()
      ..color = const Color(0xFFC97843)
      ..strokeWidth = 2 / snapshot.zoom
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, lineEnd, linePaint);

    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - direction.dx * arrowLength + normal.dx * arrowWidth,
        end.dy - direction.dy * arrowLength + normal.dy * arrowWidth,
      )
      ..lineTo(
        end.dx - direction.dx * arrowLength - normal.dx * arrowWidth,
        end.dy - direction.dy * arrowLength - normal.dy * arrowWidth,
      )
      ..close();

    canvas.drawPath(arrowPath, Paint()..color = const Color(0xFFC97843));
  }

  void _drawNode(Canvas canvas, NodeSnapshot node) {
    final rect = _nodeRect(node);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final fillPaint = Paint()..color = const Color(0xFF202733);
    final borderPaint = Paint()
      ..color = const Color(0xFF6E879F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / snapshot.zoom;

    canvas.drawRRect(rrect.shift(const Offset(0, 6)), shadowPaint);
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawNodeTitles(Canvas canvas) {
    final textureAtlases = titleAtlas.textureAtlases;
    final atlasDevicePixelRatio = titleAtlas.devicePixelRatio;
    final isAtlasUsable =
        textureAtlases.isNotEmpty &&
        atlasDevicePixelRatio != null &&
        atlasDevicePixelRatio == snapshot.devicePixelRatio;

    if (!isAtlasUsable) {
      for (final node in snapshot.nodes) {
        _drawNodeTitleDirect(canvas, node);
      }

      return;
    }

    final atlasDevicePixelRatioNonNull = atlasDevicePixelRatio;
    final nodesWithoutAtlasRect = <NodeSnapshot>[];
    final nodesByAtlasIndex = <int, List<NodeSnapshot>>{};

    for (final node in snapshot.nodes) {
      final atlasEntry = titleAtlas.entriesByNodeId[node.id];

      if (atlasEntry == null ||
          atlasEntry.atlasIndex >= textureAtlases.length) {
        nodesWithoutAtlasRect.add(node);
        continue;
      }

      nodesByAtlasIndex
          .putIfAbsent(atlasEntry.atlasIndex, () => <NodeSnapshot>[])
          .add(node);
    }

    for (final entry in nodesByAtlasIndex.entries) {
      final textureAtlas = textureAtlases[entry.key];
      final transforms = <RSTransform>[];
      final rects = <Rect>[];
      final atlasColors = <Color>[];

      for (final node in entry.value) {
        final atlasEntry = titleAtlas.entriesByNodeId[node.id]!;
        final atlasRect = atlasEntry.rect;
        final nodeRect = _nodeRect(node);
        final titleWidth = atlasRect.width / atlasDevicePixelRatioNonNull;
        final titleHeight = atlasRect.height / atlasDevicePixelRatioNonNull;
        final translateX = _snapWorldCoordinate(
          nodeRect.center.dx - titleWidth / 2,
        );
        final translateY = _snapWorldCoordinate(
          nodeRect.center.dy - titleHeight / 2,
        );

        transforms.add(
          RSTransform.fromComponents(
            rotation: 0,
            scale: 1 / atlasDevicePixelRatioNonNull,
            anchorX: 0,
            anchorY: 0,
            translateX: translateX,
            translateY: translateY,
          ),
        );
        rects.add(atlasRect);
        atlasColors.add(const Color(0xFFFFFFFF));
      }

      if (transforms.isNotEmpty) {
        canvas.drawAtlas(
          textureAtlas,
          transforms,
          rects,
          atlasColors,
          BlendMode.modulate,
          null,
          Paint()..filterQuality = FilterQuality.none,
        );
      }
    }

    for (final node in nodesWithoutAtlasRect) {
      _drawNodeTitleDirect(canvas, node);
    }
  }

  void _drawNodeTitleDirect(Canvas canvas, NodeSnapshot node) {
    final rect = _nodeRect(node);
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.name,
        style: const TextStyle(
          color: Color(0xFFE6EEF5),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: nodeTitleMaxWidth);

    textPainter.paint(
      canvas,
      rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  double _snapWorldCoordinate(double value) {
    final snapScale = snapshot.zoom * snapshot.devicePixelRatio;

    if (snapScale <= 0) {
      return value;
    }

    return (value * snapScale).roundToDouble() / snapScale;
  }

  Rect _nodeRect(NodeSnapshot node) {
    return Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      nodeSize.width,
      nodeSize.height,
    );
  }

  Offset _rectEdgeToward(Rect rect, Offset target) {
    final center = rect.center;
    final delta = target - center;

    if (delta == Offset.zero) {
      return center;
    }

    final scale = min(
      rect.width / 2 / delta.dx.abs().clamp(0.0001, double.infinity),
      rect.height / 2 / delta.dy.abs().clamp(0.0001, double.infinity),
    );

    return center + delta * scale;
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.titleAtlas != titleAtlas;
  }
}
