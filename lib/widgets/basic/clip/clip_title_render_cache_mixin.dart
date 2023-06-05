/*
  Copyright (C) 2023 Joshua Wade

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

part of 'package:anthem/model/pattern/pattern.dart';

/// This mixin adds an image cache to [PatternModel] that holds a cached version
/// of the pattern title. This cached version is recalculated every time the
/// title changes. This allows us to draw clips in the arranger much more
/// efficiently, as text layout and rendering is quite expensive when compared
/// with everything else we're drawing.

// ignore: library_private_types_in_public_api
mixin ClipTitleRenderCacheMixin on _PatternModel {
  @JsonKey(includeFromJson: false, includeToJson: false)
  @observable
  Image? renderedTitle;

  Future<void> updateClipTitleCache() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    const width = 250.0;
    const height = 15.0;

    drawPatternTitle(
      canvas: canvas,
      size: const Size(width, height),
      clipRect: const Rect.fromLTWH(0, 0, width, height),
      pattern: this as PatternModel,
      x: 0,
      y: 0,
      width: 500,
      height: 15,
      // We draw the text in white so we can recolor it when rendering from the
      // cache.
      whiteText: true,
    );

    final picture = recorder.endRecording();

    renderedTitle = await picture.toImage(width.floor(), height.floor());
  }
}
