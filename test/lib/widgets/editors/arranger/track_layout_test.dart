/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/widgets/editors/arranger/track_layout.dart';
import 'package:anthem/widgets/editors/arranger/track_row.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackLayout', () {
    test('stores row content and dividers as separate in-flow regions', () {
      final layout = TrackLayout();
      final rows = [
        _row(id: 1, depth: 0),
        _row(id: 2, depth: 1),
        _row(id: 3, depth: 0),
      ];

      layout.recalculate(
        rows: rows,
        rowHeightFor: (row) => {1: 40.0, 2: 30.0, 3: 50.0}[row.rowId]!,
        dividerHeightFor: (context) =>
            {1: 2.0, 2: 3.0, 3: 4.0}[context.resizedRow.rowId]!,
        headerWidth: TrackLayout.defaultHeaderWidth,
        viewportHeight: 0,
      );

      expect(layout.rowLayouts.map((row) => row.contentSpan), [
        const VerticalSpan(top: 0, height: 40),
        const VerticalSpan(top: 42, height: 30),
        const VerticalSpan(top: 75, height: 50),
      ]);
      expect(
        layout.rowLayouts.map((row) => _verticalSpan(row.headerBounds)),
        layout.rowLayouts.map((row) => row.contentSpan),
      );
      expect(
        layout.dividerLayouts.map((divider) => _verticalSpan(divider.bounds)),
        const [
          VerticalSpan(top: 40, height: 2),
          VerticalSpan(top: 72, height: 3),
          VerticalSpan(top: 125, height: 4),
        ],
      );
      expect(
        layout.addTrackControlSpan,
        const VerticalSpan(top: 129, height: 33),
      );
      expect(layout.contentHeight, 162);
    });

    test('uses half-open row hit regions that include divider space', () {
      final layout = _calculateSimpleLayout(
        rows: [_row(id: 1), _row(id: 2)],
        rowHeight: 40,
        dividerHeight: 2,
      );

      expect(layout.rowLayoutAtContentY(0)?.row.rowId, 1);
      expect(layout.rowLayoutAtContentY(39.999)?.row.rowId, 1);
      expect(layout.rowLayoutAtContentY(40)?.row.rowId, 1);
      expect(layout.rowLayoutAtContentY(41.999)?.row.rowId, 1);
      expect(layout.rowLayoutAtContentY(42)?.row.rowId, 2);
      expect(layout.rowLayoutAtContentY(82)?.row.rowId, 2);
      expect(layout.rowLayoutAtContentY(83.999)?.row.rowId, 2);
      expect(layout.rowLayoutAtContentY(84), isNull);
    });

    test(
      'color indicators span visible descendants and intervening dividers',
      () {
        final rows = [
          _row(id: 1, depth: 0),
          _row(id: 2, depth: 1),
          _row(id: 3, depth: 2),
          _row(id: 4, depth: 0),
        ];
        final layout = _calculateSimpleLayout(
          rows: rows,
          rowHeight: 10,
          dividerHeight: 2,
          headerWidth: TrackLayout.defaultHeaderWidth,
        );

        const lastDescendantRowIds = [3, 3, 3, 4];
        expect(
          layout.colorIndicatorLayouts.map(
            (indicator) => indicator.spansDescendants,
          ),
          [true, true, false, false],
        );
        for (final (index, indicator) in layout.colorIndicatorLayouts.indexed) {
          final rowLayout = layout.rowLayoutAt(index);
          final lastDescendantDivider = layout
              .dividerLayouts[layout.rowIdToIndex(lastDescendantRowIds[index])];

          expect(
            indicator.bounds.left,
            rows[index].trackDepth * indicator.bounds.width,
          );
          expect(indicator.bounds.top, rowLayout.contentSpan.top);
          expect(indicator.bounds.bottom, lastDescendantDivider.bounds.bottom);
          expect(rowLayout.headerBounds.left, indicator.bounds.right);
          expect(rowLayout.headerBounds.right, TrackLayout.defaultHeaderWidth);
        }
      },
    );

    test(
      'places add controls and flexible gap between regular and send rows',
      () {
        final layout = TrackLayout();
        final rows = [_row(id: 1), _row(id: 2, isSend: true)];

        layout.recalculate(
          rows: rows,
          rowHeightFor: (row) => row.rowId == 1 ? 40 : 50,
          dividerHeightFor: (_) => 2,
          headerWidth: 100,
          viewportHeight: 200,
        );

        expect(
          layout.rowLayoutForId(1).contentSpan,
          const VerticalSpan(top: 0, height: 40),
        );
        expect(
          layout.addTrackControlSpan,
          const VerticalSpan(top: 42, height: 33),
        );
        expect(
          layout.regularToSendGapSpan,
          const VerticalSpan(top: 75, height: 73),
        );
        expect(
          layout.rowLayoutForId(2).contentSpan,
          const VerticalSpan(top: 150, height: 50),
        );
        expect(layout.dividerLayouts.map((divider) => divider.resizedRowId), [
          1,
          2,
        ]);
        expect(layout.dividerLayouts.map((divider) => divider.resizeEdge), [
          TrackResizeEdge.bottom,
          TrackResizeEdge.top,
        ]);
        expect(
          layout.dividerLayouts.map((divider) => _verticalSpan(divider.bounds)),
          const [
            VerticalSpan(top: 40, height: 2),
            VerticalSpan(top: 148, height: 2),
          ],
        );

        final regularIndicator = layout.colorIndicatorLayouts[0];
        final sendIndicator = layout.colorIndicatorLayouts[1];
        expect(
          regularIndicator.bounds.top,
          layout.rowLayoutForId(1).contentSpan.top,
        );
        expect(
          regularIndicator.bounds.bottom,
          layout.dividerLayouts[0].bounds.bottom,
        );
        expect(
          sendIndicator.bounds.top,
          layout.rowLayoutForId(2).contentSpan.top,
        );
        expect(
          sendIndicator.bounds.bottom,
          layout.rowLayoutForId(2).contentSpan.bottom,
        );
        expect(layout.rowLayoutAtContentY(41.999)?.row.rowId, 1);
        expect(layout.rowLayoutAtContentY(42), isNull);
        expect(layout.rowLayoutAtContentY(147.999), isNull);
        expect(layout.rowLayoutAtContentY(148)?.row.rowId, 2);
        expect(layout.contentHeight, 200);
        expect(layout.maxScrollOffset, 0);

        layout.recalculate(
          rows: rows,
          rowHeightFor: (row) => row.rowId == 1 ? 40 : 50,
          dividerHeightFor: (_) => 2,
          headerWidth: 100,
          viewportHeight: 100,
        );

        expect(
          layout.regularToSendGapSpan,
          const VerticalSpan(top: 75, height: 0),
        );
        expect(
          layout.rowLayoutForId(2).contentSpan,
          const VerticalSpan(top: 77, height: 50),
        );
        expect(layout.contentHeight, 127);
        expect(layout.maxScrollOffset, 27);
      },
    );

    test('uses thin dividers before automation lanes', () {
      final layout = TrackLayout();
      final rows = [
        _row(id: 1), // Group 1
        _row(id: 2), // Group 2
        _row(id: 3, depth: 1), // Track 1
        _row(id: 4, depth: 1), // Track 2
        _row(id: 5, depth: 2, rowKind: TrackRowKind.automationLane),
        _row(id: 6, depth: 2, rowKind: TrackRowKind.automationLane),
        _row(id: 7, depth: 1), // Track 3
      ];

      layout.recalculate(
        rows: rows,
        rowHeightFor: (_) => 10,
        headerWidth: TrackLayout.defaultHeaderWidth,
        viewportHeight: 0,
      );

      expect(layout.dividerLayouts.map((divider) => divider.bounds.height), [
        2,
        2,
        2,
        1,
        1,
        2,
        2,
      ]);
      const dividerIndentDepths = [0, 1, 1, 2, 2, 1, 0];
      final indicatorWidth = layout.colorIndicatorLayouts.first.bounds.width;
      expect(
        layout.dividerLayouts.map((divider) => divider.bounds.left),
        dividerIndentDepths.map((depth) => depth * indicatorWidth),
      );
      expect(layout.rowLayouts.map((row) => row.contentSpan.top), [
        0,
        12,
        24,
        36,
        47,
        58,
        70,
      ]);
    });

    test('automation lanes omit indicators and use the available space', () {
      final layout = _calculateSimpleLayout(
        rows: [
          _row(id: 1),
          _row(id: 2, depth: 1, rowKind: TrackRowKind.automationLane),
          const PhantomAutomationTrackRow(
            phantomLane: PhantomAutomationLaneInfo(
              id: 3,
              parentTrackId: 1,
              target: null,
            ),
            isSendTrack: false,
            trackDepth: 1,
          ),
        ],
        rowHeight: 10,
        dividerHeight: 2,
        headerWidth: TrackLayout.defaultHeaderWidth,
      );

      expect(layout.colorIndicatorLayouts.map((indicator) => indicator.rowId), [
        1,
      ]);
      expect(layout.colorIndicatorLayouts.single.spansDescendants, isTrue);

      final ownerHeader = layout.rowLayoutForId(1).headerBounds;
      expect(layout.rowLayoutForId(2).headerBounds.left, ownerHeader.left);
      expect(layout.rowLayoutForId(3).headerBounds.left, ownerHeader.left);
    });

    test('uses the send row below a leading divider to choose its height', () {
      final layout = TrackLayout();

      layout.recalculate(
        rows: [
          _row(id: 1, isSend: true),
          _row(
            id: 2,
            depth: 1,
            isSend: true,
            rowKind: TrackRowKind.automationLane,
          ),
          _row(
            id: 3,
            depth: 1,
            isSend: true,
            rowKind: TrackRowKind.automationLane,
          ),
          _row(id: 4, depth: 1, isSend: true),
        ],
        rowHeightFor: (_) => 10,
        headerWidth: 100,
        viewportHeight: 0,
      );

      expect(layout.dividerLayouts.map((divider) => divider.bounds.height), [
        2,
        1,
        1,
        2,
      ]);
    });

    test('only increments the revision when geometry changes', () {
      final layout = TrackLayout();
      final rows = [_row(id: 1)];

      void calculate({double rowHeight = 40}) {
        layout.recalculate(
          rows: rows,
          rowHeightFor: (_) => rowHeight,
          headerWidth: 100,
          viewportHeight: 100,
        );
      }

      calculate();
      final firstRevision = layout.layoutRevision.value;
      calculate();
      expect(layout.layoutRevision.value, firstRevision);

      calculate(rowHeight: 41);
      expect(layout.layoutRevision.value, firstRevision + 1);
    });

    test('rejects duplicate row IDs', () {
      final layout = TrackLayout();

      expect(
        () => layout.recalculate(
          rows: [_row(id: 1), _row(id: 1)],
          rowHeightFor: (_) => 40,
          headerWidth: 100,
          viewportHeight: 100,
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed row ordering and hierarchy', () {
      final layout = TrackLayout();

      void calculate(List<TrackRow> rows) => layout.recalculate(
        rows: rows,
        rowHeightFor: (_) => 40,
        headerWidth: 100,
        viewportHeight: 100,
      );

      expect(
        () => calculate([_row(id: 1, isSend: true), _row(id: 2)]),
        throwsArgumentError,
      );
      expect(() => calculate([_row(id: 1, depth: 1)]), throwsArgumentError);
      expect(
        () => calculate([_row(id: 1), _row(id: 2, depth: 2)]),
        throwsArgumentError,
      );
    });
  });
}

VerticalSpan _verticalSpan(Rect bounds) =>
    VerticalSpan(top: bounds.top, height: bounds.height);

TrackLayout _calculateSimpleLayout({
  required List<TrackRow> rows,
  required double rowHeight,
  required double dividerHeight,
  double headerWidth = 100,
  double viewportHeight = 0,
}) {
  final layout = TrackLayout();
  layout.recalculate(
    rows: rows,
    rowHeightFor: (_) => rowHeight,
    dividerHeightFor: (_) => dividerHeight,
    headerWidth: headerWidth,
    viewportHeight: viewportHeight,
  );
  return layout;
}

ProjectTrackRow _row({
  required int id,
  int depth = 0,
  bool isSend = false,
  TrackRowKind rowKind = TrackRowKind.track,
}) => ProjectTrackRow(
  trackId: id,
  rowKind: rowKind,
  isSendTrack: isSend,
  trackDepth: depth,
);
