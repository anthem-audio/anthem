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
import 'package:anthem/widgets/basic/dialog/dialog_renderer.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('closing a modal restores the previous keyboard focus', (
    tester,
  ) async {
    final backgroundFocus = FocusNode();
    addTearDown(backgroundFocus.dispose);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, _) => DialogRenderer(
          child: Focus(
            focusNode: backgroundFocus,
            autofocus: true,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(backgroundFocus.hasFocus, isTrue);
    ServiceRegistry.dialogController.showDialog(content: const Text('Modal'));
    await tester.pumpAndSettle();
    expect(backgroundFocus.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(backgroundFocus.hasFocus, isTrue);
  });

  testWidgets(
    'modal dialogs isolate editor shortcuts and restore them after closing',
    (tester) async {
      var shortcuts = 0;
      var rawEvents = 0;
      late KeyboardModifiers modifiers;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (_, _) => ChangeNotifierProvider(
            create: (_) => KeyboardModifiers(),
            child: DialogRenderer(
              child: ShortcutProvider(
                child: Builder(
                  builder: (context) {
                    modifiers = context.read<KeyboardModifiers>();
                    final controller = context
                        .read<ShortcutProviderController>();
                    controller.registerShortcutHandler(
                      id: 'project',
                      global: true,
                      handler: (keys) {
                        if (!keys.matches(
                          LogicalKeySet(LogicalKeyboardKey.delete),
                        )) {
                          return false;
                        }
                        shortcuts++;
                        return true;
                      },
                    );
                    controller.registerRawKeyHandler(
                      id: 'editor',
                      handler: (_) {
                        rawEvents++;
                        return false;
                      },
                    );
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      expect(shortcuts, 1);
      final before = rawEvents;
      ServiceRegistry.dialogController.showDialog(content: const Text('Modal'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      expect(modifiers.control, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(modifiers.control, isFalse);
      expect(shortcuts, 1);
      expect(rawEvents, before);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Modal'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      expect(shortcuts, 2);
      expect(rawEvents, greaterThan(before));
    },
  );

  testWidgets(
    'dismissal calls the top dialog callback and preserves the underlying dialog',
    (tester) async {
      var underlyingDismissals = 0;
      var topDismissals = 0;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (_, _) => const DialogRenderer(child: SizedBox.expand()),
        ),
      );
      final dialogs = ServiceRegistry.dialogController;
      dialogs.showDialog(
        content: const Text('Underlying'),
        onDismiss: () => underlyingDismissals++,
      );
      dialogs.showDialog(
        content: const Text('Top'),
        onDismiss: () => topDismissals++,
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(topDismissals, 1);
      expect(underlyingDismissals, 0);
      expect(dialogs.isOpen, isTrue);
      expect(find.text('Underlying'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(underlyingDismissals, 1);
      expect(dialogs.isOpen, isFalse);
    },
  );

  testWidgets('Escape respects non-dismissible dialogs', (tester) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, _) => const DialogRenderer(child: SizedBox.expand()),
      ),
    );
    ServiceRegistry.dialogController.showDialog(
      content: const Text('Locked'),
      dismissible: false,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsOneWidget);
  });
}
