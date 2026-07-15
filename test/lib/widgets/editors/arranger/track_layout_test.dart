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
        headerWidth: 100,
        viewportHeight: 0,
      );

      expect(layout.rowLayouts.map((row) => row.contentSpan), [
        const VerticalSpan(top: 0, height: 40),
        const VerticalSpan(top: 42, height: 30),
        const VerticalSpan(top: 75, height: 50),
      ]);
      expect(layout.rowLayouts.map((row) => row.headerBounds), const [
        Rect.fromLTWH(9, 0, 91, 40),
        Rect.fromLTWH(18, 42, 82, 30),
        Rect.fromLTWH(9, 75, 91, 50),
      ]);
      expect(layout.dividerLayouts.map((divider) => divider.bounds), const [
        Rect.fromLTWH(9, 40, 91, 2),
        Rect.fromLTWH(0, 72, 100, 3),
        Rect.fromLTWH(0, 125, 100, 4),
      ]);
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
        final layout = _calculateSimpleLayout(
          rows: [
            _row(id: 1, depth: 0),
            _row(id: 2, depth: 1),
            _row(id: 3, depth: 2),
            _row(id: 4, depth: 0),
          ],
          rowHeight: 10,
          dividerHeight: 2,
          headerWidth: 100,
        );

        expect(
          layout.colorIndicatorLayouts.map((indicator) => indicator.bounds),
          const [
            Rect.fromLTWH(0, 0, 9, 36),
            Rect.fromLTWH(9, 12, 9, 24),
            Rect.fromLTWH(18, 24, 9, 12),
            Rect.fromLTWH(0, 36, 9, 12),
          ],
        );
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
        expect(layout.dividerLayouts, [
          const TrackDividerLayout(
            resizedRowId: 1,
            resizeEdge: TrackResizeEdge.bottom,
            bounds: Rect.fromLTWH(0, 40, 100, 2),
          ),
          const TrackDividerLayout(
            resizedRowId: 2,
            resizeEdge: TrackResizeEdge.top,
            bounds: Rect.fromLTWH(0, 148, 100, 2),
          ),
        ]);
        expect(
          layout.colorIndicatorLayouts.map((indicator) => indicator.bounds),
          const [Rect.fromLTWH(0, 0, 9, 42), Rect.fromLTWH(0, 150, 9, 50)],
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

ProjectTrackRow _row({required int id, int depth = 0, bool isSend = false}) =>
    ProjectTrackRow(trackId: id, isSendTrack: isSend, trackDepth: depth);
