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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../widgets/basic/clip/packed_texture.dart';

class NodeTitleAtlasEntry {
  final int nodeId;
  final String title;

  const NodeTitleAtlasEntry({required this.nodeId, required this.title});
}

class NodeTitleAtlasSnapshot {
  final List<ui.Image> textureAtlases;
  final Map<int, PackedTextureEntry> entriesByNodeId;
  final double? devicePixelRatio;

  const NodeTitleAtlasSnapshot({
    required this.textureAtlases,
    required this.entriesByNodeId,
    required this.devicePixelRatio,
  });
}

class _NodeTitleCacheKey {
  final String title;
  final double devicePixelRatio;
  final double maxTextWidth;
  final double maxTextHeight;

  const _NodeTitleCacheKey({
    required this.title,
    required this.devicePixelRatio,
    required this.maxTextWidth,
    required this.maxTextHeight,
  });

  @override
  bool operator ==(Object other) {
    return other is _NodeTitleCacheKey &&
        other.title == title &&
        other.devicePixelRatio == devicePixelRatio &&
        other.maxTextWidth == maxTextWidth &&
        other.maxTextHeight == maxTextHeight;
  }

  @override
  int get hashCode =>
      Object.hash(title, devicePixelRatio, maxTextWidth, maxTextHeight);
}

class NodeTitleAtlasController extends ChangeNotifier {
  final PackedTexture _packedTexture = PackedTexture();
  final Map<_NodeTitleCacheKey, ui.Image> _renderedTitleCache = {};
  final Map<int, String> _requestedTitlesByNodeId = {};
  final Map<int, PackedTextureEntry> _entriesByNodeId = {};

  bool _isUpdateScheduled = false;
  bool _isUpdateRunning = false;
  int _updateGeneration = 0;
  double? _requestedDevicePixelRatio;
  double? _requestedMaxTextWidth;
  double? _requestedMaxTextHeight;
  double? _atlasDevicePixelRatio;

  NodeTitleAtlasSnapshot get snapshot {
    return NodeTitleAtlasSnapshot(
      textureAtlases: _packedTexture.textureAtlases,
      entriesByNodeId: _entriesByNodeId,
      devicePixelRatio: _atlasDevicePixelRatio,
    );
  }

  void scheduleUpdate({
    required List<NodeTitleAtlasEntry> entries,
    required double devicePixelRatio,
    required double maxTextWidth,
    required double maxTextHeight,
  }) {
    if (_hasMatchingRequest(
      entries: entries,
      devicePixelRatio: devicePixelRatio,
      maxTextWidth: maxTextWidth,
      maxTextHeight: maxTextHeight,
    )) {
      return;
    }

    _requestedTitlesByNodeId
      ..clear()
      ..addEntries(entries.map((entry) => MapEntry(entry.nodeId, entry.title)));
    _requestedDevicePixelRatio = devicePixelRatio;
    _requestedMaxTextWidth = maxTextWidth;
    _requestedMaxTextHeight = maxTextHeight;
    _updateGeneration++;

    if (_isUpdateScheduled) {
      return;
    }

    _isUpdateScheduled = true;

    Future.microtask(() async {
      _isUpdateScheduled = false;

      if (_isUpdateRunning) {
        return;
      }

      _isUpdateRunning = true;

      try {
        while (true) {
          final generation = _updateGeneration;
          await _updateAtlas(generation);

          if (generation == _updateGeneration) {
            break;
          }
        }
      } finally {
        _isUpdateRunning = false;
      }
    });
  }

  bool _hasMatchingRequest({
    required List<NodeTitleAtlasEntry> entries,
    required double devicePixelRatio,
    required double maxTextWidth,
    required double maxTextHeight,
  }) {
    if (_requestedDevicePixelRatio != devicePixelRatio ||
        _requestedMaxTextWidth != maxTextWidth ||
        _requestedMaxTextHeight != maxTextHeight ||
        _requestedTitlesByNodeId.length != entries.length) {
      return false;
    }

    for (final entry in entries) {
      if (_requestedTitlesByNodeId[entry.nodeId] != entry.title) {
        return false;
      }
    }

    return true;
  }

  Future<void> _updateAtlas(int generation) async {
    final devicePixelRatio = _requestedDevicePixelRatio;
    final maxTextWidth = _requestedMaxTextWidth;
    final maxTextHeight = _requestedMaxTextHeight;

    if (devicePixelRatio == null ||
        maxTextWidth == null ||
        maxTextHeight == null) {
      return;
    }

    final nodeIdsByCacheKey = <_NodeTitleCacheKey, List<int>>{};
    final activeTitles = <String>{};

    for (final entry in _requestedTitlesByNodeId.entries) {
      activeTitles.add(entry.value);

      final cacheKey = _NodeTitleCacheKey(
        title: entry.value,
        devicePixelRatio: devicePixelRatio,
        maxTextWidth: maxTextWidth,
        maxTextHeight: maxTextHeight,
      );

      nodeIdsByCacheKey.putIfAbsent(cacheKey, () => []).add(entry.key);
    }

    _pruneRenderedTitleCache(activeTitles);

    final missingKeys = nodeIdsByCacheKey.keys
        .where((cacheKey) => !_renderedTitleCache.containsKey(cacheKey))
        .toList(growable: false);

    final renderedEntries = await Future.wait(
      missingKeys.map((cacheKey) async {
        final image = await renderNodeTitleImage(
          title: cacheKey.title,
          devicePixelRatio: cacheKey.devicePixelRatio,
          maxTextWidth: cacheKey.maxTextWidth,
          maxTextHeight: cacheKey.maxTextHeight,
        );

        return MapEntry(cacheKey, image);
      }),
    );

    if (generation != _updateGeneration) {
      for (final entry in renderedEntries) {
        entry.value.dispose();
      }

      return;
    }

    for (final entry in renderedEntries) {
      _renderedTitleCache[entry.key] = entry.value;
    }

    final orderedKeys = nodeIdsByCacheKey.keys.toList(growable: false);
    final images = orderedKeys
        .map((cacheKey) => _renderedTitleCache[cacheKey]!)
        .toList(growable: false);
    final atlasEntries = _packedTexture.drawImages(images);

    _atlasDevicePixelRatio = images.isEmpty ? null : devicePixelRatio;

    _entriesByNodeId.clear();

    for (var i = 0; i < orderedKeys.length; i++) {
      final atlasEntry = atlasEntries[i];

      for (final nodeId in nodeIdsByCacheKey[orderedKeys[i]]!) {
        _entriesByNodeId[nodeId] = atlasEntry;
      }
    }

    notifyListeners();
  }

  void _pruneRenderedTitleCache(Set<String> activeTitles) {
    _renderedTitleCache.removeWhere((cacheKey, image) {
      final shouldRemove = !activeTitles.contains(cacheKey.title);

      if (shouldRemove) {
        image.dispose();
      }

      return shouldRemove;
    });
  }

  @override
  void dispose() {
    _packedTexture.dispose();

    for (final image in _renderedTitleCache.values) {
      image.dispose();
    }

    _renderedTitleCache.clear();
    _entriesByNodeId.clear();
    super.dispose();
  }
}

Future<ui.Image> renderNodeTitleImage({
  required String title,
  required double devicePixelRatio,
  required double maxTextWidth,
  required double maxTextHeight,
}) async {
  const horizontalGutter = 4.0;
  const verticalGutter = 3.0;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paragraphStyle = ui.ParagraphStyle(
    textAlign: TextAlign.center,
    ellipsis: '...',
    maxLines: 2,
  );
  final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(
      ui.TextStyle(
        color: const Color(0xFFE6EEF5),
        fontSize: 15 * devicePixelRatio,
        fontWeight: FontWeight.w600,
      ),
    )
    ..addText(title);

  final paragraph = paragraphBuilder.build();
  final inputWidth = maxTextWidth * devicePixelRatio;
  final tileWidth = (maxTextWidth + horizontalGutter * 2) * devicePixelRatio;
  final tileHeight = (maxTextHeight + verticalGutter * 2) * devicePixelRatio;

  paragraph.layout(ui.ParagraphConstraints(width: inputWidth));
  canvas.clipRect(Rect.fromLTWH(0, 0, tileWidth, tileHeight));

  final textY =
      (verticalGutter +
              (maxTextHeight - paragraph.height / devicePixelRatio) / 2)
          .clamp(verticalGutter, verticalGutter + maxTextHeight)
          .toDouble() *
      devicePixelRatio;
  canvas.drawParagraph(
    paragraph,
    Offset(horizontalGutter * devicePixelRatio, textY),
  );

  final picture = recorder.endRecording();
  final imageWidthPx = max(1, tileWidth.ceil());
  final imageHeightPx = max(1, tileHeight.ceil());

  return picture.toImage(imageWidthPx, imageHeightPx);
}
