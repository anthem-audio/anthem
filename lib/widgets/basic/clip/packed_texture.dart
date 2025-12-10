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

import 'dart:math';
import 'dart:ui';

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
  Image? textureAtlas;

  List<Rect> drawImages(List<Image> images) {
    if (images.isEmpty) {
      return [];
    }

    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final (:rects, :atlasSize) = _layout(images);

    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final rect = rects[i];

      final srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );

      canvas.drawImageRect(image, srcRect, rect, Paint());
    }

    final picture = pictureRecorder.endRecording();
    textureAtlas = picture.toImageSync(
      atlasSize.width.ceil(),
      atlasSize.height.ceil(),
    );

    return rects;
  }

  ({List<Rect> rects, Size atlasSize}) _layout(
    List<Image> images, [
    double maxWidth = 2048.0,
  ]) {
    if (images.isEmpty) {
      return (rects: [], atlasSize: Size.zero);
    }

    var currentX = 0.0;
    var currentY = 0.0;
    var rowHeight = 0.0;

    final rects = <Rect>[];

    for (final image in images) {
      if (currentX + image.width > maxWidth) {
        // Move to next row.
        currentX = 0.0;
        currentY += rowHeight;
        rowHeight = 0.0;
      }

      rects.add(
        Rect.fromLTWH(
          currentX,
          currentY,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );

      currentX += image.width;
      rowHeight = max(rowHeight, image.height.toDouble());
    }

    return (rects: rects, atlasSize: Size(maxWidth, currentY + rowHeight));
  }
}
