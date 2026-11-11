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

import 'package:anthem/widgets/basic/text_box.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'text editing and platform selection updates keep the standalone theme',
    (tester) async {
      final controller = await _pumpTextBox(tester);
      await tester.enterText(find.byType(TextField), 'Anthem');
      expect(controller.text, 'Anthem');
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );

      tester.testTextInput.updateEditingValue(
        controller.value.copyWith(selection: _selection),
      );
      await tester.pump();
      expect(controller.selection, _selection);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).selectionColor,
        _selectionColor,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'desktop select-all shortcut works with standalone Material',
    (tester) async {
      final controller = await _pumpTextBox(tester);
      await tester.enterText(find.byType(TextField), 'Anthem');

      final modifier = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();

      expect(controller.selection, _selection);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.desktop(),
    // On web, the browser performs select-all and sends a platform selection
    // update. Synthetic Flutter key events cannot exercise that DOM behavior.
    skip: kIsWeb,
  );
}

const _selectionColor = Color(0xFF28D1AA);
const _selection = TextSelection(baseOffset: 0, extentOffset: 6);

Future<TextEditingController> _pumpTextBox(WidgetTester tester) async {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: _selectionColor,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: TextBox(
            controller: controller,
            focusNode: focusNode,
            width: 200,
            height: 30,
          ),
        ),
      ),
    ),
  );
  return controller;
}
