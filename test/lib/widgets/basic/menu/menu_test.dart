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

import 'dart:ui' show PointerDeviceKind;

import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/widgets/basic/color_picker.dart';
import 'package:anthem/widgets/basic/color_picker_button.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable;
import 'package:provider/provider.dart';

void main() {
  testWidgets('outside click closes the menu and reaches the base widget', (
    tester,
  ) async {
    final menuController = AnthemMenuController();
    var pointerDownCalls = 0;
    var pointerUpCalls = 0;
    var tapCalls = 0;

    await tester.pumpWidget(
      _MenuTestApp(
        child: Column(
          children: [
            Menu(
              menuController: menuController,
              menuDef: MenuDef(children: [AnthemMenuItem(text: 'Menu item')]),
              child: _TestButton(
                buttonKey: const ValueKey('menu-anchor'),
                label: 'Open menu',
                onTap: menuController.toggle,
              ),
            ),
            const SizedBox(height: 100),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tapCalls += 1,
              child: Listener(
                key: const ValueKey('outside-target'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => pointerDownCalls += 1,
                onPointerUp: (_) => pointerUpCalls += 1,
                child: const SizedBox(width: 180, height: 48),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('menu-anchor')));
    await tester.pump();
    expect(find.text('Menu item'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('outside-target')));
    await tester.pump();

    expect(find.text('Menu item'), findsNothing);
    expect(pointerDownCalls, equals(1));
    expect(pointerUpCalls, equals(1));
    expect(tapCalls, equals(1));
  });

  testWidgets('clicking the same anchor toggles its menu closed', (
    tester,
  ) async {
    final menuController = AnthemMenuController();

    await tester.pumpWidget(
      _MenuTestApp(
        child: Menu(
          menuController: menuController,
          menuDef: MenuDef(children: [AnthemMenuItem(text: 'Menu item')]),
          child: _TestButton(
            buttonKey: const ValueKey('menu-anchor'),
            label: 'Toggle menu',
            onTap: menuController.toggle,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('menu-anchor')));
    await tester.pump();
    expect(find.text('Menu item'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('menu-anchor')));
    await tester.pump();
    expect(find.text('Menu item'), findsNothing);
  });

  testWidgets('clicking another anchor closes the first and opens the second', (
    tester,
  ) async {
    final firstController = AnthemMenuController();
    final secondController = AnthemMenuController();

    await tester.pumpWidget(
      _MenuTestApp(
        child: Row(
          children: [
            Menu(
              menuController: firstController,
              menuDef: MenuDef(children: [AnthemMenuItem(text: 'First item')]),
              child: _TestButton(
                buttonKey: const ValueKey('first-anchor'),
                label: 'First',
                onTap: firstController.toggle,
              ),
            ),
            Menu(
              menuController: secondController,
              menuDef: MenuDef(children: [AnthemMenuItem(text: 'Second item')]),
              child: _TestButton(
                buttonKey: const ValueKey('second-anchor'),
                label: 'Second',
                onTap: secondController.toggle,
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('first-anchor')));
    await tester.pump();
    expect(find.text('First item'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('second-anchor')));
    await tester.pump();

    expect(find.text('First item'), findsNothing);
    expect(find.text('Second item'), findsOneWidget);
  });

  testWidgets('submenus participate in the root menu tap region', (
    tester,
  ) async {
    final menuController = AnthemMenuController();
    var nestedSelections = 0;

    await tester.pumpWidget(
      _MenuTestApp(
        child: Menu(
          menuController: menuController,
          menuDef: MenuDef(
            children: [
              AnthemMenuItem(
                text: 'More',
                submenu: MenuDef(
                  children: [
                    AnthemMenuItem(
                      text: 'Nested item',
                      onSelected: () => nestedSelections += 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          child: _TestButton(
            buttonKey: const ValueKey('menu-anchor'),
            label: 'Open menu',
            onTap: menuController.toggle,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('menu-anchor')));
    await tester.pump();
    await tester.tap(find.text('More'));
    await tester.pump();
    expect(find.text('Nested item'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Nested item')),
    );
    await tester.pump();

    expect(find.text('More'), findsOneWidget);
    expect(find.text('Nested item'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(nestedSelections, equals(1));
    expect(find.text('More'), findsNothing);
    expect(find.text('Nested item'), findsNothing);
  });

  testWidgets('toggling the anchor closes the entire submenu tree', (
    tester,
  ) async {
    final menuController = AnthemMenuController();

    await tester.pumpWidget(
      _MenuTestApp(
        child: Menu(
          menuController: menuController,
          menuDef: MenuDef(
            children: [
              AnthemMenuItem(
                text: 'More',
                submenu: MenuDef(
                  children: [AnthemMenuItem(text: 'Nested item')],
                ),
              ),
            ],
          ),
          child: _TestButton(
            buttonKey: const ValueKey('menu-anchor'),
            label: 'Open menu',
            onTap: menuController.toggle,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('menu-anchor')));
    await tester.pump();
    await tester.tap(find.text('More'));
    await tester.pump();
    expect(find.text('Nested item'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('menu-anchor')));
    await tester.pump();

    expect(find.text('More'), findsNothing);
    expect(find.text('Nested item'), findsNothing);
  });

  testWidgets(
    'menu controller group switches open menus on hover without opening idle menus',
    (tester) async {
      final firstController = AnthemMenuController();
      final secondController = AnthemMenuController();
      final controllerGroup = AnthemMenuControllerGroup([
        firstController,
        secondController,
      ]);

      await tester.pumpWidget(
        _MenuTestApp(
          child: Row(
            children: [
              Menu(
                menuController: firstController,
                menuControllerGroup: controllerGroup,
                menuDef: MenuDef(
                  children: [AnthemMenuItem(text: 'First item')],
                ),
                child: _TestButton(
                  buttonKey: const ValueKey('first-anchor'),
                  label: 'First',
                  onTap: firstController.toggle,
                ),
              ),
              Menu(
                menuController: secondController,
                menuControllerGroup: controllerGroup,
                menuDef: MenuDef(
                  children: [AnthemMenuItem(text: 'Second item')],
                ),
                child: _TestButton(
                  buttonKey: const ValueKey('second-anchor'),
                  label: 'Second',
                  onTap: secondController.toggle,
                ),
              ),
            ],
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      const outsidePosition = Offset(500, 400);
      await mouse.addPointer(location: outsidePosition);
      await tester.pump();

      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('first-anchor'))),
      );
      await tester.pump();
      expect(find.text('First item'), findsNothing);
      expect(find.text('Second item'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('first-anchor')));
      await tester.pump();
      expect(find.text('First item'), findsOneWidget);

      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('second-anchor'))),
      );
      await tester.pump();
      expect(find.text('First item'), findsNothing);
      expect(find.text('Second item'), findsOneWidget);

      await mouse.moveTo(outsidePosition);
      await tester.pump();
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('second-anchor'))),
      );
      await tester.pump();
      expect(find.text('Second item'), findsOneWidget);

      await tester.tapAt(outsidePosition);
      await tester.pump();
      expect(find.text('Second item'), findsNothing);

      await mouse.moveTo(outsidePosition);
      await tester.pump();
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('first-anchor'))),
      );
      await tester.pump();
      expect(find.text('First item'), findsNothing);
    },
  );

  testWidgets('hover switching closes the current submenu tree', (
    tester,
  ) async {
    final firstController = AnthemMenuController();
    final secondController = AnthemMenuController();
    final controllerGroup = AnthemMenuControllerGroup([
      firstController,
      secondController,
    ]);

    await tester.pumpWidget(
      _MenuTestApp(
        child: Row(
          children: [
            Menu(
              menuController: firstController,
              menuControllerGroup: controllerGroup,
              menuDef: MenuDef(
                children: [
                  AnthemMenuItem(
                    text: 'More',
                    submenu: MenuDef(
                      children: [AnthemMenuItem(text: 'Nested item')],
                    ),
                  ),
                ],
              ),
              child: _TestButton(
                buttonKey: const ValueKey('first-anchor'),
                label: 'First',
                onTap: firstController.toggle,
              ),
            ),
            Menu(
              menuController: secondController,
              menuControllerGroup: controllerGroup,
              menuDef: MenuDef(children: [AnthemMenuItem(text: 'Second item')]),
              child: _TestButton(
                buttonKey: const ValueKey('second-anchor'),
                label: 'Second',
                onTap: secondController.toggle,
              ),
            ),
          ],
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(500, 400));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('first-anchor')));
    await tester.pump();
    await tester.tap(find.text('More'));
    await tester.pump();
    expect(find.text('Nested item'), findsOneWidget);

    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('second-anchor'))),
    );
    await tester.pump();

    expect(find.text('More'), findsNothing);
    expect(find.text('Nested item'), findsNothing);
    expect(find.text('Second item'), findsOneWidget);
  });

  testWidgets('hover switching cancels a pending submenu open', (tester) async {
    final firstController = AnthemMenuController();
    final secondController = AnthemMenuController();
    final controllerGroup = AnthemMenuControllerGroup([
      firstController,
      secondController,
    ]);

    await tester.pumpWidget(
      _MenuTestApp(
        child: Row(
          children: [
            Menu(
              menuController: firstController,
              menuControllerGroup: controllerGroup,
              menuDef: MenuDef(
                children: [
                  AnthemMenuItem(
                    text: 'More',
                    submenu: MenuDef(
                      children: [AnthemMenuItem(text: 'Nested item')],
                    ),
                  ),
                ],
              ),
              child: _TestButton(
                buttonKey: const ValueKey('first-anchor'),
                label: 'First',
                onTap: firstController.toggle,
              ),
            ),
            Menu(
              menuController: secondController,
              menuControllerGroup: controllerGroup,
              menuDef: MenuDef(children: [AnthemMenuItem(text: 'Second item')]),
              child: _TestButton(
                buttonKey: const ValueKey('second-anchor'),
                label: 'Second',
                onTap: secondController.toggle,
              ),
            ),
          ],
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(500, 400));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('first-anchor')));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('More')));
    await tester.pump();

    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('second-anchor'))),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('More'), findsNothing);
    expect(find.text('Nested item'), findsNothing);
    expect(find.text('Second item'), findsOneWidget);
  });

  testWidgets(
    'color picker popover dismisses without blocking the base widget',
    (tester) async {
      var outsideTapCalls = 0;
      final hue = Observable(0.0);
      final palette = Observable(AnthemColorPaletteKind.normal);

      await tester.pumpWidget(
        _MenuTestApp(
          child: Column(
            children: [
              ColorPickerButton(getValues: () => (hue.value, palette.value)),
              const SizedBox(height: 150),
              _TestButton(
                buttonKey: const ValueKey('outside-target'),
                label: 'Outside',
                onTap: () => outsideTapCalls += 1,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byType(ColorPickerButton));
      await tester.pump();
      expect(find.byType(ColorPicker), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('outside-target')));
      await tester.pump();

      expect(find.byType(ColorPicker), findsNothing);
      expect(outsideTapCalls, equals(1));
    },
  );
}

class _MenuTestApp extends StatelessWidget {
  final Widget child;
  final ScreenOverlayViewModel viewModel = ScreenOverlayViewModel();
  late final ScreenOverlayController controller = ScreenOverlayController(
    viewModel: viewModel,
  );

  _MenuTestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: MultiProvider(
            providers: [
              Provider.value(value: viewModel),
              Provider.value(value: controller),
            ],
            child: Observer(
              builder: (context) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Align(alignment: Alignment.topLeft, child: child),
                    ),
                    ...viewModel.entries.values.map(
                      (entry) => entry.builder(context),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  final Key buttonKey;
  final String label;
  final VoidCallback onTap;

  const _TestButton({
    required this.buttonKey,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 100,
        height: 32,
        child: Center(child: Text(label)),
      ),
    );
  }
}
