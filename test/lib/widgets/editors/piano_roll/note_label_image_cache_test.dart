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

import 'package:anthem/widgets/editors/piano_roll/note_label_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteLabelImageCache', () {
    late NoteLabelImageCache cache;

    setUp(() {
      cache = NoteLabelImageCache();
    });

    tearDown(() {
      cache.dispose();
    });

    test('renders labels at the requested device pixel ratio', () async {
      await cache.init(2);

      final image = cache.get(60)!;

      expect(cache.initialized, isTrue);
      expect(cache.isInitializedFor(2), isTrue);
      expect(image.width, noteLabelWidth * 2);
      expect(image.height, noteLabelHeight * 2);
    });

    test(
      'replaces cached labels when the device pixel ratio changes',
      () async {
        await cache.init(1);

        expect(cache.isInitializedFor(1), isTrue);
        expect(cache.get(60)!.width, noteLabelWidth);

        await cache.init(2);

        expect(cache.isInitializedFor(1), isFalse);
        expect(cache.isInitializedFor(2), isTrue);
        expect(cache.get(60)!.width, noteLabelWidth * 2);
      },
    );
  });
}
