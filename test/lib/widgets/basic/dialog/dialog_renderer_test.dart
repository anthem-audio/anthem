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
  testWidgets(
    'markdown dialog works without Material and remains interactive',
    (tester) async {
      String? tappedLink;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, child) =>
              const DialogRenderer(child: SizedBox.expand()),
        ),
      );

      ServiceRegistry.dialogController.showMarkdownDialog(
        title: 'Markdown',
        markdown:
            '[Read more](https://example.com)\n\n'
            '${List.generate(40, (index) => 'Paragraph $index').join('\n\n')}',
        onTapLink: (text, href, title) => tappedLink = href,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Read more'));
      expect(tappedLink, 'https://example.com');

      final scrollbar = find.byType(RawScrollbar);
      final scrollable = find.descendant(
        of: scrollbar,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      final bounds = tester.getRect(scrollbar);
      await tester.dragFrom(
        Offset(bounds.right - 6, bounds.top + 10),
        const Offset(0, 100),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissible dialog closes when backdrop is tapped', (
    tester,
  ) async {
    var backgroundTapCalls = 0;
    await _pumpDialogRenderer(
      tester,
      onBackgroundTap: () => backgroundTapCalls += 1,
    );

    ServiceRegistry.dialogController.showDialog(
      title: 'Dismissible',
      content: const Text('Dismissible content'),
    );
    await tester.pump();

    expect(find.text('Dismissible content'), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pump();

    expect(find.text('Dismissible content'), findsNothing);
    expect(backgroundTapCalls, equals(0));
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

Future<void> _pumpDialogRenderer(
  WidgetTester tester, {
  VoidCallback? onBackgroundTap,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 12),
        child: DialogRenderer(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBackgroundTap,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}
