/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

mixin _ClipTitleRenderCacheMixin on _PatternModel {
  @hide
  Image? renderedTitle;

  @hide
  Rect? clipTitleAtlasRect;

  Future<void> updateClipTitleCache() async {
    // This will happen in unit tests that are using the model. This should
    // never happen when running the app; if it does, something is wrong.
    if (mainWindowKey.currentContext == null) {
      return;
    }

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final devicePixelRatio = widgets.View.of(
      mainWindowKey.currentContext!,
    ).devicePixelRatio;

    final inputWidth = 250.0 * devicePixelRatio;
    final inputHeight = 15.0 * devicePixelRatio;

    drawPatternTitle(
      canvas: canvas,
      size: Size(inputWidth, inputHeight),
      clipRect: Rect.fromLTWH(0, 0, inputWidth, inputHeight),
      pattern: this as PatternModel,
      x: 3,
      y: 0,
      width: inputWidth,
      height: inputHeight,
      // We draw the text in white so we can recolor it when rendering from the
      // cache.
      overrideTextColor: const Color(0xFFFFFFFF),
      devicePixelRatio: devicePixelRatio,
    );

    final picture = recorder.endRecording();

    final (width, height) = getClipTitleSize(
      devicePixelRatio: devicePixelRatio,
      pattern: this as PatternModel,
    );

    renderedTitle = await picture.toImage(
      (width * devicePixelRatio).ceil(),
      (height * devicePixelRatio).ceil(),
    );

    getFirstAncestorOfType<SequencerModel>()
        .scheduleClipTitleTextureAtlasUpdate();
  }
}
