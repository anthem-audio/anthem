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

import 'dart:ui' as ui;

import 'package:anthem/widgets/editors/arranger/rendering/clip_title_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('renderClipTitleImage', () {
    test(
      'keeps the title inset stable in logical pixels across DPRs',
      () async {
        ui.Image? dpr1Image;
        ui.Image? dpr2Image;

        try {
          dpr1Image = await renderClipTitleImage(
            title: 'Scale',
            devicePixelRatio: 1,
          );
          dpr2Image = await renderClipTitleImage(
            title: 'Scale',
            devicePixelRatio: 2,
          );

          final dpr1Bounds = await _alphaBounds(dpr1Image);
          final dpr2Bounds = await _alphaBounds(dpr2Image);

          expect(dpr2Bounds.left / 2, closeTo(dpr1Bounds.left, 1.25));
        } finally {
          dpr1Image?.dispose();
          dpr2Image?.dispose();
        }
      },
    );
  });
}

Future<_AlphaBounds> _alphaBounds(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  if (byteData == null) {
    throw StateError('Failed to read bytes from image.');
  }

  final bytes = byteData.buffer.asUint8List();
  var left = image.width;
  var right = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final alphaIndex = (y * image.width + x) * 4 + 3;

      if (bytes[alphaIndex] == 0) {
        continue;
      }

      if (x < left) {
        left = x;
      }

      if (x > right) {
        right = x;
      }
    }
  }

  if (right == -1) {
    throw StateError('Image has no visible pixels.');
  }

  return _AlphaBounds(left: left);
}

class _AlphaBounds {
  final int left;

  const _AlphaBounds({required this.left});
}
