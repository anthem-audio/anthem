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

import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenOverlayController', () {
    test('handle close removes entry and calls onClose once', () {
      final viewModel = ScreenOverlayViewModel();
      final controller = ScreenOverlayController(viewModel: viewModel);
      int onCloseCalls = 0;

      final handle = controller.show(
        ScreenOverlayEntry(
          builder: (_) => const SizedBox.shrink(),
          onClose: () => onCloseCalls += 1,
        ),
      );

      expect(viewModel.entries, hasLength(1));

      handle.close();

      expect(viewModel.entries, isEmpty);
      expect(onCloseCalls, equals(1));

      handle.close();

      expect(viewModel.entries, isEmpty);
      expect(onCloseCalls, equals(1));
    });

    test('clear closes all active entries and empties the overlay stack', () {
      final viewModel = ScreenOverlayViewModel();
      final controller = ScreenOverlayController(viewModel: viewModel);
      int firstOnCloseCalls = 0;
      int secondOnCloseCalls = 0;

      controller.show(
        ScreenOverlayEntry(
          builder: (_) => const SizedBox.shrink(),
          onClose: () => firstOnCloseCalls += 1,
        ),
      );
      final secondHandle = controller.show(
        ScreenOverlayEntry(
          builder: (_) => const SizedBox.shrink(),
          onClose: () => secondOnCloseCalls += 1,
        ),
      );

      expect(viewModel.entries, hasLength(2));

      controller.clear();

      expect(viewModel.entries, isEmpty);
      expect(firstOnCloseCalls, equals(1));
      expect(secondOnCloseCalls, equals(1));

      secondHandle.close();

      expect(firstOnCloseCalls, equals(1));
      expect(secondOnCloseCalls, equals(1));
    });
  });
}
