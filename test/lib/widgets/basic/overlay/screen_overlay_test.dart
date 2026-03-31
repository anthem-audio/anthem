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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'ScreenOverlay provides controller access and clears active overlays on pointer release and cancel',
    (WidgetTester tester) async {
      late ScreenOverlayController providedController;
      late ScreenOverlayViewModel providedViewModel;
      int onCloseCalls = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 300,
            child: ScreenOverlay(
              child: Builder(
                builder: (BuildContext context) {
                  providedController = Provider.of<ScreenOverlayController>(
                    context,
                    listen: false,
                  );
                  providedViewModel = Provider.of<ScreenOverlayViewModel>(
                    context,
                    listen: false,
                  );

                  return const SizedBox(key: ValueKey<String>('base-child'));
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('base-child')), findsOneWidget);
      expect(
        identical(providedController, ServiceRegistry.screenOverlayController),
        isTrue,
      );
      expect(providedViewModel.entries, isEmpty);

      providedController.show(
        ScreenOverlayEntry(
          builder: (_) => const Positioned(
            left: 10,
            top: 10,
            child: SizedBox(
              key: ValueKey<String>('overlay-entry'),
              width: 20,
              height: 20,
            ),
          ),
          onClose: () => onCloseCalls += 1,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('overlay-entry')),
        findsOneWidget,
      );
      expect(providedViewModel.entries, hasLength(1));

      await tester.tapAt(const Offset(200, 200));
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('overlay-entry')), findsNothing);
      expect(providedViewModel.entries, isEmpty);
      expect(onCloseCalls, equals(1));

      providedController.show(
        ScreenOverlayEntry(
          builder: (_) => const Positioned(
            left: 10,
            top: 10,
            child: SizedBox(
              key: ValueKey<String>('overlay-entry'),
              width: 20,
              height: 20,
            ),
          ),
          onClose: () => onCloseCalls += 1,
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(200, 200));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('overlay-entry')), findsNothing);
      expect(providedViewModel.entries, isEmpty);
      expect(onCloseCalls, equals(2));
    },
  );
}
