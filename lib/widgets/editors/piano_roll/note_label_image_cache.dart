/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'dart:ui';

import 'helpers.dart';

const noteLabelHeight = 20;
const noteLabelWidth = 32;

class NoteLabelImageCache {
  List<Image>? _cache;
  double? _devicePixelRatio;
  double? _initializingDevicePixelRatio;
  int _initGeneration = 0;

  bool get initialized =>
      _cache != null || _initializingDevicePixelRatio != null;

  bool isInitializedFor(double devicePixelRatio) {
    return _devicePixelRatio == devicePixelRatio ||
        _initializingDevicePixelRatio == devicePixelRatio;
  }

  Future<void> init(double devicePixelRatio) async {
    assert(devicePixelRatio > 0);

    if (isInitializedFor(devicePixelRatio)) {
      return;
    }

    final generation = ++_initGeneration;
    _initializingDevicePixelRatio = devicePixelRatio;
    _devicePixelRatio = null;
    _disposeCache();

    final cache = <Image>[];

    try {
      for (var i = 0; i < 128; i++) {
        final string = keyToString(i);

        final recorder = PictureRecorder();

        final builder = ParagraphBuilder(
          ParagraphStyle(
            fontWeight: FontWeight.w400,
            fontSize: noteLabelHeight * 0.75,
          ),
        )..addText(string);
        final paragraph = builder.build()
          ..layout(const ParagraphConstraints(width: 1000));

        final canvas = Canvas(recorder)..scale(devicePixelRatio);

        canvas.drawParagraph(paragraph, Offset.zero);

        final image = await recorder.endRecording().toImage(
          (noteLabelWidth * devicePixelRatio).ceil(),
          (noteLabelHeight * devicePixelRatio).ceil(),
        );
        cache.add(image);
      }
    } catch (_) {
      for (final image in cache) {
        image.dispose();
      }

      if (generation == _initGeneration) {
        _initializingDevicePixelRatio = null;
      }

      rethrow;
    }

    if (generation != _initGeneration) {
      for (final image in cache) {
        image.dispose();
      }

      return;
    }

    _cache = cache;
    _devicePixelRatio = devicePixelRatio;
    _initializingDevicePixelRatio = null;
  }

  Image? get(int midiNote) => _cache?.elementAtOrNull(midiNote);

  void dispose() {
    _initGeneration++;
    _devicePixelRatio = null;
    _initializingDevicePixelRatio = null;
    _disposeCache();
  }

  void _disposeCache() {
    final cache = _cache;
    if (cache == null) {
      return;
    }

    for (final image in cache) {
      image.dispose();
    }

    _cache = null;
  }
}

NoteLabelImageCache noteLabelImageCache = NoteLabelImageCache();
