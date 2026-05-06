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

import 'package:anthem/widgets/basic/clip/packed_texture.dart';
import 'package:flutter_test/flutter_test.dart';

const _redColor = ui.Color(0xFFFF0000);
const _greenColor = ui.Color(0xFF00FF00);
const _blueColor = ui.Color(0xFF0000FF);
const _atlasWidth = 64.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PackedTexture.drawImages', () {
    test('returns empty rects and keeps atlas null for empty input', () async {
      final packedTexture = PackedTexture(maxWidth: _atlasWidth);

      final entries = packedTexture.drawImages(<ui.Image>[]);

      expect(entries, isEmpty);
      expect(packedTexture.textureAtlases, isEmpty);
    });

    test('clears the previous atlas when input becomes empty', () async {
      final packedTexture = PackedTexture(maxWidth: _atlasWidth);
      final red = await _makeSolidImage(width: 10, height: 6, color: _redColor);

      final initialEntries = packedTexture.drawImages([red]);

      expect(initialEntries, isNotEmpty);
      expect(packedTexture.textureAtlases, hasLength(1));

      final clearedEntries = packedTexture.drawImages(<ui.Image>[]);

      expect(clearedEntries, isEmpty);
      expect(packedTexture.textureAtlases, isEmpty);

      red.dispose();
    });

    test('packs a single image at origin with expected atlas size', () async {
      final packedTexture = PackedTexture(maxWidth: _atlasWidth);
      final red = await _makeSolidImage(width: 10, height: 6, color: _redColor);

      final entries = packedTexture.drawImages([red]);
      final atlas = packedTexture.textureAtlases.single;

      expect(_entryRects(entries), [ui.Rect.fromLTWH(0, 0, 10, 6)]);
      expect(_entryAtlasIndices(entries), [0]);
      expect(atlas.width, equals(10));
      expect(atlas.height, equals(6));
      expect(await _pixelAt(atlas, 5, 3), equals(_redColor));

      red.dispose();
      packedTexture.dispose();
    });

    test('packs multiple images on one row in input order', () async {
      final packedTexture = PackedTexture(maxWidth: _atlasWidth);
      final red = await _makeSolidImage(width: 10, height: 4, color: _redColor);
      final green = await _makeSolidImage(
        width: 12,
        height: 6,
        color: _greenColor,
      );
      final blue = await _makeSolidImage(
        width: 8,
        height: 5,
        color: _blueColor,
      );

      final entries = packedTexture.drawImages([red, green, blue]);
      final atlas = packedTexture.textureAtlases.single;

      expect(_entryRects(entries), [
        ui.Rect.fromLTWH(0, 0, 10, 4),
        ui.Rect.fromLTWH(10, 0, 12, 6),
        ui.Rect.fromLTWH(22, 0, 8, 5),
      ]);
      expect(_entryAtlasIndices(entries), [0, 0, 0]);
      expect(atlas.width, equals(30));
      expect(atlas.height, equals(6));

      expect(await _pixelAt(atlas, 5, 2), equals(_redColor));
      expect(await _pixelAt(atlas, 16, 3), equals(_greenColor));
      expect(await _pixelAt(atlas, 26, 2), equals(_blueColor));

      red.dispose();
      green.dispose();
      blue.dispose();
      packedTexture.dispose();
    });

    test('wraps to a new row when image exceeds max atlas width', () async {
      final packedTexture = PackedTexture(maxWidth: _atlasWidth);
      final red = await _makeSolidImage(
        width: 40,
        height: 10,
        color: _redColor,
      );
      final green = await _makeSolidImage(
        width: 30,
        height: 20,
        color: _greenColor,
      );
      final blue = await _makeSolidImage(
        width: 12,
        height: 8,
        color: _blueColor,
      );

      final entries = packedTexture.drawImages([red, green, blue]);
      final atlas = packedTexture.textureAtlases.single;

      expect(_entryRects(entries), [
        ui.Rect.fromLTWH(0, 0, 40, 10),
        ui.Rect.fromLTWH(0, 10, 30, 20),
        ui.Rect.fromLTWH(30, 10, 12, 8),
      ]);
      expect(_entryAtlasIndices(entries), [0, 0, 0]);
      expect(atlas.width, equals(42));
      expect(atlas.height, equals(30));

      expect(await _pixelAt(atlas, 20, 5), equals(_redColor));
      expect(await _pixelAt(atlas, 15, 20), equals(_greenColor));
      expect(await _pixelAt(atlas, 35, 14), equals(_blueColor));

      red.dispose();
      green.dispose();
      blue.dispose();
      packedTexture.dispose();
    });

    test('exact width boundary stays on same row', () async {
      final packedTexture = PackedTexture(maxWidth: _atlasWidth);
      final red = await _makeSolidImage(width: 32, height: 7, color: _redColor);
      final green = await _makeSolidImage(
        width: 32,
        height: 9,
        color: _greenColor,
      );
      final blue = await _makeSolidImage(
        width: 1,
        height: 5,
        color: _blueColor,
      );

      final entries = packedTexture.drawImages([red, green, blue]);
      final atlas = packedTexture.textureAtlases.single;

      expect(_entryRects(entries), [
        ui.Rect.fromLTWH(0, 0, 32, 7),
        ui.Rect.fromLTWH(32, 0, 32, 9),
        ui.Rect.fromLTWH(0, 9, 1, 5),
      ]);
      expect(_entryAtlasIndices(entries), [0, 0, 0]);
      expect(atlas.width, equals(_atlasWidth.toInt()));
      expect(atlas.height, equals(14));

      expect(await _pixelAt(atlas, 16, 3), equals(_redColor));
      expect(await _pixelAt(atlas, 48, 4), equals(_greenColor));
      expect(await _pixelAt(atlas, 0, 11), equals(_blueColor));

      red.dispose();
      green.dispose();
      blue.dispose();
      packedTexture.dispose();
    });

    test('creates a new atlas page when rows exceed max height', () async {
      final packedTexture = PackedTexture(maxWidth: 20, maxHeight: 15);
      final red = await _makeSolidImage(width: 12, height: 7, color: _redColor);
      final green = await _makeSolidImage(
        width: 12,
        height: 6,
        color: _greenColor,
      );
      final blue = await _makeSolidImage(
        width: 10,
        height: 5,
        color: _blueColor,
      );

      final entries = packedTexture.drawImages([red, green, blue]);
      final atlases = packedTexture.textureAtlases;

      expect(_entryRects(entries), [
        ui.Rect.fromLTWH(0, 0, 12, 7),
        ui.Rect.fromLTWH(0, 7, 12, 6),
        ui.Rect.fromLTWH(0, 0, 10, 5),
      ]);
      expect(_entryAtlasIndices(entries), [0, 0, 1]);
      expect(atlases, hasLength(2));
      expect(atlases[0].width, equals(12));
      expect(atlases[0].height, equals(13));
      expect(atlases[1].width, equals(10));
      expect(atlases[1].height, equals(5));

      expect(await _pixelAt(atlases[0], 6, 3), equals(_redColor));
      expect(await _pixelAt(atlases[0], 6, 10), equals(_greenColor));
      expect(await _pixelAt(atlases[1], 5, 2), equals(_blueColor));

      red.dispose();
      green.dispose();
      blue.dispose();
      packedTexture.dispose();
    });

    test('applies gutter around each image', () async {
      final packedTexture = PackedTexture(maxWidth: 30, gutter: 2);
      final red = await _makeSolidImage(width: 10, height: 4, color: _redColor);
      final green = await _makeSolidImage(
        width: 8,
        height: 6,
        color: _greenColor,
      );

      final entries = packedTexture.drawImages([red, green]);
      final atlas = packedTexture.textureAtlases.single;

      expect(_entryRects(entries), [
        ui.Rect.fromLTWH(2, 2, 10, 4),
        ui.Rect.fromLTWH(16, 2, 8, 6),
      ]);
      expect(_entryAtlasIndices(entries), [0, 0]);
      expect(atlas.width, equals(26));
      expect(atlas.height, equals(10));

      expect(await _pixelAt(atlas, 7, 3), equals(_redColor));
      expect(await _pixelAt(atlas, 20, 4), equals(_greenColor));

      red.dispose();
      green.dispose();
      packedTexture.dispose();
    });

    test('throws when an image exceeds the atlas page size', () async {
      final packedTexture = PackedTexture(maxWidth: 10, maxHeight: 10);
      final red = await _makeSolidImage(
        width: 11,
        height: 10,
        color: _redColor,
      );

      expect(() => packedTexture.drawImages([red]), throwsStateError);
      expect(packedTexture.textureAtlases, isEmpty);

      red.dispose();
    });
  });
}

List<ui.Rect> _entryRects(List<PackedTextureEntry> entries) {
  return entries.map((entry) => entry.rect).toList();
}

List<int> _entryAtlasIndices(List<PackedTextureEntry> entries) {
  return entries.map((entry) => entry.atlasIndex).toList();
}

Future<ui.Image> _makeSolidImage({
  required int width,
  required int height,
  required ui.Color color,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );

  return recorder.endRecording().toImage(width, height);
}

Future<ui.Color> _pixelAt(ui.Image image, int x, int y) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  if (byteData == null) {
    throw StateError('Failed to read bytes from image.');
  }

  final bytes = byteData.buffer.asUint8List();
  final index = (y * image.width + x) * 4;

  return ui.Color.fromARGB(
    bytes[index + 3],
    bytes[index],
    bytes[index + 1],
    bytes[index + 2],
  );
}
