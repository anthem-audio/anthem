/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anthem/widgets/editors/arranger/widgets/arranger_diagonal_pattern.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rounds display scaling to the nearest integer with ties down', () {
    expect(arrangerPatternPixelScaleForDevicePixelRatio(1), 1);
    expect(arrangerPatternPixelScaleForDevicePixelRatio(1.25), 1);
    expect(arrangerPatternPixelScaleForDevicePixelRatio(1.5), 1);
    expect(arrangerPatternPixelScaleForDevicePixelRatio(1.5001), 2);
    expect(arrangerPatternPixelScaleForDevicePixelRatio(2), 2);
    expect(arrangerPatternPixelScaleForDevicePixelRatio(2.5), 2);
    expect(arrangerPatternPixelScaleForDevicePixelRatio(2.5001), 3);
  });

  for (final (devicePixelRatio, expectedPixelScale) in [
    (1.0, 1),
    (1.25, 1),
    (1.5, 1),
    (2.0, 2),
  ]) {
    testWidgets(
      'renders and repeats the pixel pattern at ${devicePixelRatio}x',
      (tester) async {
        tester.view.devicePixelRatio = devicePixelRatio;
        addTearDown(tester.view.resetDevicePixelRatio);

        final boundaryKey = GlobalKey();
        const physicalSize = 24.0;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.square(
                dimension: physicalSize / devicePixelRatio,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: const ArrangerDiagonalPattern(),
                ),
              ),
            ),
          ),
        );
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = boundary.toImageSync(pixelRatio: devicePixelRatio);
        addTearDown(image.dispose);

        expect(image.width, physicalSize);
        expect(image.height, physicalSize);
        final bytes = await tester.runAsync(() => _rgbaBytes(image));
        if (bytes == null) throw StateError('Failed to read image pixels.');

        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final cellX = (x ~/ expectedPixelScale) % 6;
            final cellY = (y ~/ expectedPixelScale) % 6;
            final isStripe = cellX == cellY || cellX == (cellY + 1) % 6;
            final expectedChannel = isStripe ? 0x4E : 0x2F;
            final byteOffset = (y * image.width + x) * 4;

            expect(bytes[byteOffset], expectedChannel, reason: 'red at $x,$y');
            expect(
              bytes[byteOffset + 1],
              expectedChannel,
              reason: 'green at $x,$y',
            );
            expect(
              bytes[byteOffset + 2],
              expectedChannel,
              reason: 'blue at $x,$y',
            );
            expect(bytes[byteOffset + 3], 0xFF, reason: 'alpha at $x,$y');
          }
        }
      },
    );
  }
}

Future<Uint8List> _rgbaBytes(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) throw StateError('Failed to read image pixels.');
  return byteData.buffer.asUint8List();
}
