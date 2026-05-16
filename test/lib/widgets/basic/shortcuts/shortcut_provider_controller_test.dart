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

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

KeyDownEvent _keyDown({
  required PhysicalKeyboardKey physicalKey,
  required LogicalKeyboardKey logicalKey,
}) {
  return KeyDownEvent(
    physicalKey: physicalKey,
    logicalKey: logicalKey,
    timeStamp: Duration.zero,
  );
}

KeyUpEvent _keyUp({
  required PhysicalKeyboardKey physicalKey,
  required LogicalKeyboardKey logicalKey,
}) {
  return KeyUpEvent(
    physicalKey: physicalKey,
    logicalKey: logicalKey,
    timeStamp: Duration.zero,
  );
}

void main() {
  group('ShortcutProviderController', () {
    late ShortcutProviderController controller;

    setUp(() {
      controller = ShortcutProviderController();
    });

    test('dispatches shortcuts to global and active handlers by default', () {
      final globalShortcuts = <LogicalKeySet>[];
      final activeShortcuts = <LogicalKeySet>[];

      controller.registerShortcutHandler(
        id: 'global',
        global: true,
        handler: globalShortcuts.add,
      );
      controller.registerShortcutHandler(
        id: 'active',
        handler: activeShortcuts.add,
      );
      controller.setActiveConsumer('active');

      controller.handleKeyDown(
        _keyDown(
          physicalKey: PhysicalKeyboardKey.controlLeft,
          logicalKey: LogicalKeyboardKey.controlLeft,
        ),
      );
      controller.handleKeyDown(
        _keyDown(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
        ),
      );

      expect(globalShortcuts, hasLength(2));
      expect(activeShortcuts, hasLength(2));
      expect(
        activeShortcuts.last.matches(
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA),
        ),
        isTrue,
      );
    });

    test(
      'suppresses shortcuts while still dispatching raw handlers and tracking keys',
      () {
        var rawCallCount = 0;
        var shortcutCallCount = 0;

        controller.registerRawKeyHandler(
          id: 'raw',
          handler: (_) {
            rawCallCount++;
            return false;
          },
        );
        controller.registerShortcutHandler(
          id: 'active',
          handler: (_) {
            shortcutCallCount++;
          },
        );
        controller.setActiveConsumer('active');

        controller.handleKeyDown(
          _keyDown(
            physicalKey: PhysicalKeyboardKey.keyB,
            logicalKey: LogicalKeyboardKey.keyB,
          ),
          dispatchShortcuts: false,
        );

        expect(rawCallCount, equals(1));
        expect(shortcutCallCount, equals(0));
        expect(controller.pressedKeys, contains(LogicalKeyboardKey.keyB));
      },
    );

    test('can suppress raw handler dispatch for key down and key up', () {
      var rawCallCount = 0;

      controller.registerRawKeyHandler(
        id: 'raw',
        handler: (_) {
          rawCallCount++;
          return false;
        },
      );

      controller.handleKeyDown(
        _keyDown(
          physicalKey: PhysicalKeyboardKey.controlLeft,
          logicalKey: LogicalKeyboardKey.controlLeft,
        ),
        dispatchRaw: false,
        dispatchShortcuts: false,
      );
      controller.handleKeyUp(
        _keyUp(
          physicalKey: PhysicalKeyboardKey.controlLeft,
          logicalKey: LogicalKeyboardKey.controlLeft,
        ),
        dispatchRaw: false,
      );

      expect(rawCallCount, equals(0));
      expect(
        controller.pressedKeys,
        isNot(contains(LogicalKeyboardKey.controlLeft)),
      );
    });

    test(
      'raw handlers can still swallow events before pressed key tracking',
      () {
        controller.registerRawKeyHandler(id: 'raw', handler: (_) => true);

        controller.handleKeyDown(
          _keyDown(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
          ),
          dispatchShortcuts: false,
        );

        expect(
          controller.pressedKeys,
          isNot(contains(LogicalKeyboardKey.keyA)),
        );
      },
    );
  });

  group('registerEditorDeleteShortcut', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('registers Delete on non-macOS platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final shortcutManager = ShortcutBehaviors();
      var callCount = 0;

      registerEditorDeleteShortcut(shortcutManager, () {
        callCount++;
      });

      shortcutManager.handleShortcut(LogicalKeySet(LogicalKeyboardKey.delete));
      shortcutManager.handleShortcut(
        LogicalKeySet(LogicalKeyboardKey.backspace),
      );

      expect(callCount, equals(1));
    });

    test('registers Backspace as Delete on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final shortcutManager = ShortcutBehaviors();
      var callCount = 0;

      registerEditorDeleteShortcut(shortcutManager, () {
        callCount++;
      });

      shortcutManager.handleShortcut(
        LogicalKeySet(LogicalKeyboardKey.backspace),
      );
      shortcutManager.handleShortcut(LogicalKeySet(LogicalKeyboardKey.delete));

      expect(callCount, equals(2));
    });
  });
}
