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

import 'dart:ui';

import 'helpers.dart';

const noteLabelHeight = 20;
const noteLabelWidth = 32;

class NoteLabelImageCache {
  List<Image>? _cache;
  bool initialized = false;

  void init(double devicePixelRatio) async {
    initialized = true;
    final cache = <Image>[];

    for (var i = 0; i < 128; i++) {
      final string = keyToString(i);

      final recorder = PictureRecorder();

      final builder = ParagraphBuilder(
        ParagraphStyle(
          fontWeight: FontWeight.w400,
          fontSize: noteLabelHeight * 0.75 * devicePixelRatio,
        ),
      )..addText(string);
      final paragraph = builder.build()
        ..layout(const ParagraphConstraints(width: 1000));

      final canvas = Canvas(recorder);

      canvas.drawParagraph(paragraph, const Offset(0, 0));

      final image = await recorder.endRecording().toImage(
        (noteLabelWidth * devicePixelRatio).toInt(),
        (noteLabelHeight * devicePixelRatio).toInt(),
      );
      cache.add(image);
    }

    _cache = cache;
  }

  Image? get(int midiNote) => _cache?.elementAtOrNull(midiNote);
}

NoteLabelImageCache noteLabelImageCache = NoteLabelImageCache();
