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

import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Icons;

const _items = [
  DropdownItem(id: 'a', name: 'Alpha'),
  DropdownItem(id: 'b', name: 'Beta'),
  DropdownItem(id: 'c', name: 'Gamma'),
];

void main() {
  testWidgets('selection reports IDs and follows parent updates', (
    tester,
  ) async {
    final selected = ValueNotifier<String?>('a');
    final changes = <String?>[];
    addTearDown(selected.dispose);
    await _pump(
      tester,
      ValueListenableBuilder<String?>(
        valueListenable: selected,
        builder: (_, id, _) => Dropdown(
          width: 120,
          height: 24,
          items: _items,
          selectedID: id,
          onChanged: (id) {
            changes.add(id);
            selected.value = id;
          },
        ),
      ),
    );
    await _open(tester);
    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(changes, ['b']);
    expect(find.text('Beta'), findsOneWidget);
    selected.value = 'c';
    await tester.pump();
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('local selection and wheel cycling include the nullable choice', (
    tester,
  ) async {
    final changes = <String?>[];
    await _pump(
      tester,
      Dropdown(width: 120, height: 24, items: _items, onChanged: changes.add),
    );
    await _open(tester);
    await tester.tap(find.text('Beta'));
    await tester.pump();
    await _scroll(tester, 100);
    expect(find.text('Gamma'), findsOneWidget);
    await _scroll(tester, 100);
    expect(find.text('(none)'), findsOneWidget);
    await _scroll(tester, -100);
    expect(find.text('Gamma'), findsOneWidget);
    expect(changes, ['b', 'c', null, 'c']);
  });

  testWidgets('disabling or removing a dropdown closes its menu', (
    tester,
  ) async {
    var enabled = true;
    var visible = true;
    late StateSetter update;
    final changes = <String?>[];
    await _pump(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return visible
              ? Dropdown(
                  width: 120,
                  height: 24,
                  items: _items,
                  selectedID: 'a',
                  enabled: enabled,
                  onChanged: changes.add,
                )
              : const SizedBox.shrink();
        },
      ),
    );
    await _open(tester);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsNothing);
    await tester.tap(find.byType(Dropdown));
    await _scroll(tester, 100);
    expect(find.text('Beta'), findsNothing);
    expect(changes, isEmpty);

    update(() => enabled = true);
    await tester.pump();
    await _open(tester);
    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wheel selection can be disabled without disabling the menu', (
    tester,
  ) async {
    final changes = <String?>[];
    await _pump(
      tester,
      Dropdown(
        width: 120,
        height: 24,
        items: _items,
        selectedID: 'a',
        enableScrollSelection: false,
        onChanged: changes.add,
      ),
    );
    await _scroll(tester, 100);
    expect(changes, isEmpty);
    await _open(tester);
    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(changes, ['b']);
  });

  testWidgets('short captions fit the joined control', (tester) async {
    await _pump(
      tester,
      const Dropdown(
        width: 80,
        height: 24,
        selectedID: 'b',
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
        items: _items,
      ),
    );
    expect(
      tester.renderObject<RenderParagraph>(find.text('Beta')).didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline text and narrow icon dropdowns remain usable', (
    tester,
  ) async {
    String? tool;
    await _pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Dropdown(
            height: 20,
            horizontalExpand: false,
            selectedID: 'a',
            items: _items,
          ),
          const SizedBox(width: 10),
          Dropdown(
            width: 41,
            height: 20,
            showNameOnButton: false,
            selectedID: 'pencil',
            items: [
              DropdownItem(
                id: 'pencil',
                name: 'Pencil',
                icon: Icons.tools.pencil,
              ),
              DropdownItem(id: 'erase', name: 'Erase', icon: Icons.tools.erase),
            ],
            onChanged: (id) => tool = id,
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Dropdown).last);
    await tester.pump();
    await tester.tap(find.text('Erase'));
    await tester.pump();
    expect(tool, 'erase');
    expect(find.text('Erase'), findsNothing);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: ScreenOverlay(child: Center(child: child)),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(Dropdown));
  await tester.pump();
}

Future<void> _scroll(WidgetTester tester, double delta) async {
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: tester.getCenter(find.byType(Dropdown)),
      scrollDelta: Offset(0, delta),
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pump();
}
