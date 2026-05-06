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

import 'dart:math';
import 'dart:ui';

class PackedTextureEntry {
  final int atlasIndex;
  final Rect rect;

  const PackedTextureEntry({required this.atlasIndex, required this.rect});
}

class _PackedTexturePage {
  final List<int> imageIndices = [];
  final List<Rect> rects = [];
  double currentX = 0.0;
  double currentY = 0.0;
  double rowHeight = 0.0;
  double usedWidth = 0.0;
  double usedHeight = 0.0;
}

/// Holds a texture that can be used to render clip titles using drawAtlas.
///
/// ### Background
///
/// Drawing clip titles is surprisingly hard. The naive way is to just draw
/// text, but doing so is far too expensive. The solution is caching the clip
/// title to an image - doing so dramatically reduces the cost of rendering the
/// text.
///
/// The naive way to cache is just to draw each title to an image using a
/// PictureRecorder. This is fast, but its primary downside is that each title
/// must be drawn with a separate draw call. Flutter is not able to optimize
/// this very well.
///
/// The best way to draw clip titles is to use Canvas.drawAtlas once per frame.
/// This is much faster, as it allows Flutter to optimize drawing at the raster
/// level, and offers an order of magnitude improvement to draw time when
/// rendering pattern titles.
///
/// ### [PackedTexture]
///
/// The purpose of this class is to provide a texture that have multiple things
/// drawn to it. This allows us to use drawAtlas to draw multiple cached
/// drawings in a single draw call.
class PackedTexture {
  final double maxWidth;
  final double maxHeight;
  final double gutter;
  final List<Image> textureAtlases = [];

  PackedTexture({
    this.maxWidth = 2048.0,
    this.maxHeight = 4096.0,
    this.gutter = 0.0,
  }) : assert(maxWidth > 0),
       assert(maxHeight > 0),
       assert(gutter >= 0);

  List<PackedTextureEntry> drawImages(List<Image> images) {
    if (images.isEmpty) {
      dispose();
      return [];
    }

    final (:entries, :pages) = _layout(images);
    final newAtlases = <Image>[];

    try {
      for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        final page = pages[pageIndex];
        final pictureRecorder = PictureRecorder();
        final canvas = Canvas(pictureRecorder);

        for (var i = 0; i < page.imageIndices.length; i++) {
          final image = images[page.imageIndices[i]];
          final rect = page.rects[i];
          final srcRect = Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          );

          canvas.drawImageRect(image, srcRect, rect, Paint());
        }

        final picture = pictureRecorder.endRecording();
        newAtlases.add(
          picture.toImageSync(
            max(1, page.usedWidth.ceil()),
            max(1, page.usedHeight.ceil()),
          ),
        );
      }
    } catch (_) {
      for (final atlas in newAtlases) {
        atlas.dispose();
      }

      rethrow;
    }

    dispose();
    textureAtlases.addAll(newAtlases);

    return entries;
  }

  ({List<PackedTextureEntry> entries, List<_PackedTexturePage> pages}) _layout(
    List<Image> images,
  ) {
    if (images.isEmpty) {
      return (entries: [], pages: []);
    }

    final pages = <_PackedTexturePage>[_PackedTexturePage()];
    final entries = <PackedTextureEntry>[];

    for (var imageIndex = 0; imageIndex < images.length; imageIndex++) {
      final image = images[imageIndex];
      final tileWidth = image.width + gutter * 2;
      final tileHeight = image.height + gutter * 2;

      if (tileWidth > maxWidth || tileHeight > maxHeight) {
        throw StateError(
          'PackedTexture image ${image.width}x${image.height} exceeds the '
          'configured page size $maxWidth x $maxHeight.',
        );
      }

      var page = pages.last;
      var nextX = page.currentX;
      var nextY = page.currentY;
      var nextRowHeight = page.rowHeight;

      if (nextX + tileWidth > maxWidth) {
        nextX = 0.0;
        nextY += nextRowHeight;
        nextRowHeight = 0.0;
      }

      if (nextY + tileHeight > maxHeight) {
        page = _PackedTexturePage();
        pages.add(page);
        nextX = 0.0;
        nextY = 0.0;
        nextRowHeight = 0.0;
      }

      final rect = Rect.fromLTWH(
        nextX + gutter,
        nextY + gutter,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final atlasIndex = pages.length - 1;

      page.imageIndices.add(imageIndex);
      page.rects.add(rect);
      page.currentX = nextX + tileWidth;
      page.currentY = nextY;
      page.rowHeight = max(nextRowHeight, tileHeight);
      page.usedWidth = max(page.usedWidth, page.currentX);
      page.usedHeight = max(page.usedHeight, page.currentY + page.rowHeight);

      entries.add(PackedTextureEntry(atlasIndex: atlasIndex, rect: rect));
    }

    return (entries: entries, pages: pages);
  }

  void dispose() {
    for (final atlas in textureAtlases) {
      atlas.dispose();
    }

    textureAtlases.clear();
  }
}
