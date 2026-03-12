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

part of 'package:anthem/model/sequencer.dart';

class _ClipTitleCacheKey {
  final String title;
  final double devicePixelRatio;

  const _ClipTitleCacheKey({
    required this.title,
    required this.devicePixelRatio,
  });

  @override
  bool operator ==(Object other) {
    return other is _ClipTitleCacheKey &&
        other.title == title &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(title, devicePixelRatio);
}

mixin _ClipTitleAtlasMixin on _SequencerModel {
  @hide
  bool isClipTitleTextureAtlasUpdateScheduled = false;

  @hide
  bool isClipTitleTextureAtlasUpdateRunning = false;

  @hide
  int clipTitleTextureAtlasUpdateGeneration = 0;

  @hide
  PackedTexture patternTitleTexture = PackedTexture();

  @hide
  double? clipTitleTextureAtlasDevicePixelRatio;

  @hide
  final Map<Id, Rect> clipTitleAtlasRectsByPatternId = {};

  @hide
  final Map<_ClipTitleCacheKey, Image> renderedClipTitleCache = {};

  void invalidateClipTitleAtlasEntryForPattern(Id patternId) {
    clipTitleAtlasRectsByPatternId.remove(patternId);
    scheduleClipTitleTextureAtlasUpdate();
  }

  void scheduleClipTitleTextureAtlasUpdate() {
    clipTitleTextureAtlasUpdateGeneration++;

    if (isClipTitleTextureAtlasUpdateScheduled) {
      return;
    }

    isClipTitleTextureAtlasUpdateScheduled = true;

    Future.microtask(() async {
      isClipTitleTextureAtlasUpdateScheduled = false;

      if (isClipTitleTextureAtlasUpdateRunning) {
        return;
      }

      isClipTitleTextureAtlasUpdateRunning = true;

      try {
        while (true) {
          final generation = clipTitleTextureAtlasUpdateGeneration;

          await _updateClipTitleTextureAtlas(generation);

          if (generation == clipTitleTextureAtlasUpdateGeneration) {
            break;
          }
        }
      } finally {
        isClipTitleTextureAtlasUpdateRunning = false;
      }
    });
  }

  Future<void> _updateClipTitleTextureAtlas(int generation) async {
    final context = mainWindowKey.currentContext;
    if (context == null) {
      return;
    }

    final devicePixelRatio = widgets.View.of(context).devicePixelRatio;
    final patternIdsByCacheKey = <_ClipTitleCacheKey, List<Id>>{};
    final activeTitles = <String>{};

    for (final entry in patterns.entries) {
      activeTitles.add(entry.value.name);

      final cacheKey = _ClipTitleCacheKey(
        title: entry.value.name,
        devicePixelRatio: devicePixelRatio,
      );

      patternIdsByCacheKey.putIfAbsent(cacheKey, () => []).add(entry.key);
    }

    _pruneRenderedClipTitleCache(activeTitles);

    final missingKeys = patternIdsByCacheKey.keys
        .where((cacheKey) => !renderedClipTitleCache.containsKey(cacheKey))
        .toList(growable: false);

    final renderedEntries = await Future.wait(
      missingKeys.map((cacheKey) async {
        final image = await renderClipTitleImage(
          title: cacheKey.title,
          devicePixelRatio: cacheKey.devicePixelRatio,
        );

        return MapEntry(cacheKey, image);
      }),
    );

    if (generation != clipTitleTextureAtlasUpdateGeneration) {
      for (final entry in renderedEntries) {
        entry.value.dispose();
      }
      return;
    }

    for (final entry in renderedEntries) {
      renderedClipTitleCache[entry.key] = entry.value;
    }

    final orderedKeys = patternIdsByCacheKey.keys.toList(growable: false);
    final images = orderedKeys
        .map((cacheKey) => renderedClipTitleCache[cacheKey]!)
        .toList(growable: false);

    final rects = patternTitleTexture.drawImages(images);

    clipTitleTextureAtlasDevicePixelRatio = images.isEmpty
        ? null
        : devicePixelRatio;

    clipTitleAtlasRectsByPatternId.clear();

    for (var i = 0; i < orderedKeys.length; i++) {
      final rect = rects[i];
      final patternIds = patternIdsByCacheKey[orderedKeys[i]]!;

      for (final patternId in patternIds) {
        clipTitleAtlasRectsByPatternId[patternId] = rect;
      }
    }
  }

  void _pruneRenderedClipTitleCache(Set<String> activeTitles) {
    renderedClipTitleCache.removeWhere((cacheKey, image) {
      final shouldRemove = !activeTitles.contains(cacheKey.title);

      if (shouldRemove) {
        image.dispose();
      }

      return shouldRemove;
    });
  }

  void disposeClipTitleTextureAtlasCache() {
    patternTitleTexture.textureAtlas?.dispose();
    patternTitleTexture.textureAtlas = null;
    clipTitleTextureAtlasDevicePixelRatio = null;
    clipTitleAtlasRectsByPatternId.clear();

    for (final image in renderedClipTitleCache.values) {
      image.dispose();
    }

    renderedClipTitleCache.clear();
  }
}
