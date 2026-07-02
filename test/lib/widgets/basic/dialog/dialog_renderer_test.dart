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
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dismissible dialog closes when backdrop is tapped', (
    tester,
  ) async {
    await _pumpDialogRenderer(tester);

    ServiceRegistry.dialogController.showDialog(
      title: 'Dismissible',
      content: const Text('Dismissible content'),
    );
    await tester.pump();

    expect(find.text('Dismissible content'), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pump();

    expect(find.text('Dismissible content'), findsNothing);
  });

  testWidgets('non-dismissible dialog ignores backdrop taps', (tester) async {
    await _pumpDialogRenderer(tester);

    ServiceRegistry.dialogController.showDialog(
      title: 'Locked',
      content: const Text('Locked content'),
      dismissible: false,
    );
    await tester.pump();

    expect(find.text('Locked content'), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pump();

    expect(find.text('Locked content'), findsOneWidget);
  });
}

Future<void> _pumpDialogRenderer(WidgetTester tester) async {
  await tester.pumpWidget(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 12),
        child: DialogRenderer(child: SizedBox.expand()),
      ),
    ),
  );
}
