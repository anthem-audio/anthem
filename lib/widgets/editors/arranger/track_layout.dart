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

import 'dart:math';
import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/editors/arranger/track_row.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

typedef TrackRowHeightResolver = double Function(TrackRow row);
typedef TrackDividerHeightResolver =
    double Function(TrackDividerContext context);

/// The vertical interval occupied by an element in scrollable content space.
///
/// Spans use half-open bounds: [top] is included and [bottom] is excluded.
@immutable
class VerticalSpan {
  final double top;
  final double height;

  const VerticalSpan({required this.top, required this.height})
    : assert(top >= 0),
      assert(height >= 0);

  double get bottom => top + height;

  bool contains(double y) => y >= top && y < bottom;

  @override
  bool operator ==(Object other) =>
      other is VerticalSpan && other.top == top && other.height == height;

  @override
  int get hashCode => Object.hash(top, height);
}

/// The calculator inputs available when deciding a divider's visual height.
@immutable
class TrackDividerContext {
  final TrackRow resizedRow;
  final TrackResizeEdge resizeEdge;

  /// The row immediately below the divider, or `null` when the divider is
  /// followed by a section boundary or the end of the layout.
  final TrackRow? rowBelow;

  const TrackDividerContext({
    required this.resizedRow,
    required this.resizeEdge,
    required this.rowBelow,
  });
}

enum TrackResizeEdge { top, bottom }

/// Scroll-independent geometry shared by a track header and arranger row.
@immutable
class TrackRowLayout {
  final int rowIndex;
  final TrackRow row;
  final VerticalSpan contentSpan;

  /// Bounds for the header-content widget, excluding any color indicator and
  /// the resize divider.
  final Rect headerBounds;

  const TrackRowLayout({
    required this.rowIndex,
    required this.row,
    required this.contentSpan,
    required this.headerBounds,
  });

  @override
  bool operator ==(Object other) =>
      other is TrackRowLayout &&
      other.rowIndex == rowIndex &&
      other.row.rowId == row.rowId &&
      other.row.rowKind == row.rowKind &&
      other.row.isSendTrack == row.isSendTrack &&
      other.row.trackDepth == row.trackDepth &&
      other.contentSpan == contentSpan &&
      other.headerBounds == headerBounds;

  @override
  int get hashCode => Object.hash(
    rowIndex,
    row.rowId,
    row.rowKind,
    row.isSendTrack,
    row.trackDepth,
    contentSpan,
    headerBounds,
  );
}

/// Geometry for a color indicator owned by [rowId].
///
/// Automation lanes do not have color indicators.
///
/// An indicator starts alongside its owning row and extends through the final
/// visible descendant. For regular tracks, it includes the final descendant's
/// bottom divider. For send tracks, it ends at the final descendant's content
/// bottom because that row's divider precedes its content.
@immutable
class TrackColorIndicatorLayout {
  final Id rowId;
  final Rect bounds;
  final bool spansDescendants;

  const TrackColorIndicatorLayout({
    required this.rowId,
    required this.bounds,
    required this.spansDescendants,
  });

  @override
  bool operator ==(Object other) =>
      other is TrackColorIndicatorLayout &&
      other.rowId == rowId &&
      other.bounds == bounds &&
      other.spansDescendants == spansDescendants;

  @override
  int get hashCode => Object.hash(rowId, bounds, spansDescendants);
}

/// Visual and interaction geometry for a row's resize divider.
///
/// [bounds] consumes space in the vertical layout but is not part of either
/// row's content height. Regular rows place their divider below their content;
/// send rows place it above. The divider widget layer can derive a larger
/// interaction region from these visual bounds.
@immutable
class TrackDividerLayout {
  final Id resizedRowId;
  final TrackResizeEdge resizeEdge;
  final Rect bounds;

  const TrackDividerLayout({
    required this.resizedRowId,
    required this.resizeEdge,
    required this.bounds,
  });

  @override
  bool operator ==(Object other) =>
      other is TrackDividerLayout &&
      other.resizedRowId == resizedRowId &&
      other.resizeEdge == resizeEdge &&
      other.bounds == bounds;

  @override
  int get hashCode => Object.hash(resizedRowId, resizeEdge, bounds);
}

/// Calculates and stores scroll-independent track geometry.
///
/// Row content regions and header bounds share the same vertical span. Regular
/// row dividers follow their target row; send-row dividers precede it. Changing
/// a divider height moves the appropriate rows without changing any row's
/// configured content height. Color indicators are derived from the same
/// layout snapshot.
class TrackLayout {
  static const defaultHeaderWidth = 292.0;
  static const defaultColorIndicatorWidth = 52.0;
  static const standardDividerHeight = 2.0;
  static const automationLaneDividerHeight = 1.0;
  static const defaultAddTrackControlHeight = 33.0;

  static const _rowLayoutEquality = ListEquality<TrackRowLayout>();
  static const _indicatorLayoutEquality =
      ListEquality<TrackColorIndicatorLayout>();
  static const _dividerLayoutEquality = ListEquality<TrackDividerLayout>();

  List<TrackRowLayout> _rowLayouts = const [];
  List<TrackColorIndicatorLayout> _colorIndicatorLayouts = const [];
  List<TrackDividerLayout> _dividerLayouts = const [];

  final _rowIdToIndex = <Id, int>{};
  final _trackIdToIndex = <Id, int>{};
  final _trackIndexToId = <int, Id>{};

  double _headerWidth = 0;
  double _viewportHeight = 0;
  double _contentHeight = 0;
  VerticalSpan _addTrackControlSpan = const VerticalSpan(top: 0, height: 0);
  VerticalSpan _regularToSendGapSpan = const VerticalSpan(top: 0, height: 0);

  final layoutRevision = ValueNotifier<int>(0);

  List<TrackRowLayout> get rowLayouts => _rowLayouts;
  List<TrackColorIndicatorLayout> get colorIndicatorLayouts =>
      _colorIndicatorLayouts;
  List<TrackDividerLayout> get dividerLayouts => _dividerLayouts;

  double get headerWidth => _headerWidth;
  double get viewportHeight => _viewportHeight;
  double get contentHeight => _contentHeight;
  double get maxScrollOffset => max(0, contentHeight - viewportHeight);
  VerticalSpan get addTrackControlSpan => _addTrackControlSpan;
  VerticalSpan get regularToSendGapSpan => _regularToSendGapSpan;

  int? tryRowIdToIndex(Id rowId) => _rowIdToIndex[rowId];
  int rowIdToIndex(Id rowId) => _rowIdToIndex[rowId]!;
  TrackRowLayout? tryRowLayoutForId(Id rowId) {
    final index = tryRowIdToIndex(rowId);
    return index == null ? null : _rowLayouts[index];
  }

  TrackRowLayout rowLayoutForId(Id rowId) => _rowLayouts[rowIdToIndex(rowId)];
  TrackRowLayout rowLayoutAt(int index) => _rowLayouts[index];

  int? tryTrackIdToIndex(Id trackId) => _trackIdToIndex[trackId];
  int trackIdToIndex(Id trackId) => _trackIdToIndex[trackId]!;
  Id? tryTrackIndexToId(int index) => _trackIndexToId[index];
  Id trackIndexToId(int index) => _trackIndexToId[index]!;

  /// Returns the row containing [y] in main arranger content space.
  ///
  /// A row owns both its content span and its visual divider. Add-track controls
  /// and the regular-to-send gap do not belong to a row.
  TrackRowLayout? rowLayoutAtContentY(double y) {
    var low = 0;
    var high = _rowLayouts.length - 1;

    while (low <= high) {
      final middle = (low + high) >> 1;
      final layout = _rowLayouts[middle];
      final contentSpan = layout.contentSpan;
      final dividerBounds = _dividerLayouts[middle].bounds;
      final hitTop = min(contentSpan.top, dividerBounds.top);
      final hitBottom = max(contentSpan.bottom, dividerBounds.bottom);

      if (y < hitTop) {
        high = middle - 1;
      } else if (y >= hitBottom) {
        low = middle + 1;
      } else {
        return layout;
      }
    }

    return null;
  }

  void recalculate({
    required Iterable<TrackRow> rows,
    required TrackRowHeightResolver rowHeightFor,
    required double headerWidth,
    required double viewportHeight,
    TrackDividerHeightResolver? dividerHeightFor,
    double colorIndicatorWidth = defaultColorIndicatorWidth,
    double addTrackControlHeight = defaultAddTrackControlHeight,
  }) {
    _validateNonNegativeFinite(headerWidth, 'headerWidth');
    _validateNonNegativeFinite(viewportHeight, 'viewportHeight');
    _validateNonNegativeFinite(colorIndicatorWidth, 'colorIndicatorWidth');
    _validateNonNegativeFinite(addTrackControlHeight, 'addTrackControlHeight');

    final rowsList = rows.toList(growable: false);
    final rowIds = <Id>{};
    var isInSendSection = false;
    TrackRow? previousRow;
    for (final row in rowsList) {
      if (!rowIds.add(row.rowId)) {
        throw ArgumentError.value(row.rowId, 'rows', 'Duplicate row ID');
      }

      if (row.trackDepth < 0) {
        throw ArgumentError.value(
          row.trackDepth,
          'rows',
          'Track depth must be non-negative',
        );
      }
      if (row.isSendTrack) {
        isInSendSection = true;
      } else if (isInSendSection) {
        throw ArgumentError.value(
          row.rowId,
          'rows',
          'Regular rows cannot follow send rows',
        );
      }

      final startsSection =
          previousRow == null || previousRow.isSendTrack != row.isSendTrack;
      if (startsSection && row.trackDepth != 0) {
        throw ArgumentError.value(
          row.trackDepth,
          'rows',
          'The first row in a section must be top-level',
        );
      }
      if (!startsSection && row.trackDepth > previousRow.trackDepth + 1) {
        throw ArgumentError.value(
          row.trackDepth,
          'rows',
          'Track depth cannot skip a hierarchy level',
        );
      }

      previousRow = row;
    }

    final sendSectionStart = rowsList.indexWhere((row) => row.isSendTrack);
    final sectionBreakIndex = sendSectionStart < 0
        ? rowsList.length
        : sendSectionStart;
    final resolveDividerHeight = dividerHeightFor ?? _defaultDividerHeightFor;

    final rowHeights = <double>[];
    final dividerHeights = <double>[];
    for (final (index, row) in rowsList.indexed) {
      final rowHeight = rowHeightFor(row);
      _validatePositiveFinite(rowHeight, 'rowHeightFor(${row.rowId})');
      rowHeights.add(rowHeight);

      final resizeEdge = row.isSendTrack
          ? TrackResizeEdge.top
          : TrackResizeEdge.bottom;
      final nextRow = index + 1 < rowsList.length ? rowsList[index + 1] : null;
      final rowBelow = row.isSendTrack
          ? row
          : nextRow?.isSendTrack == false
          ? nextRow
          : null;
      final dividerHeight = resolveDividerHeight(
        TrackDividerContext(
          resizedRow: row,
          resizeEdge: resizeEdge,
          rowBelow: rowBelow,
        ),
      );
      _validatePositiveFinite(dividerHeight, 'dividerHeightFor(${row.rowId})');
      dividerHeights.add(dividerHeight);
    }

    final naturalHeight =
        rowHeights.fold(0.0, (sum, height) => sum + height) +
        dividerHeights.fold(0.0, (sum, height) => sum + height) +
        addTrackControlHeight;
    final regularToSendGapHeight = max(0.0, viewportHeight - naturalHeight);

    final nextRows = <TrackRowLayout>[];
    final nextDividers = <TrackDividerLayout>[];
    var position = 0.0;
    var addTrackControlSpan = const VerticalSpan(top: 0, height: 0);
    var regularToSendGapSpan = const VerticalSpan(top: 0, height: 0);

    void addSectionBreak() {
      addTrackControlSpan = VerticalSpan(
        top: position,
        height: addTrackControlHeight,
      );
      position = addTrackControlSpan.bottom;
      regularToSendGapSpan = VerticalSpan(
        top: position,
        height: regularToSendGapHeight,
      );
      position = regularToSendGapSpan.bottom;
    }

    void addDivider({
      required TrackRow row,
      required int rowIndex,
      required TrackResizeEdge resizeEdge,
      required int indentDepth,
    }) {
      final dividerLeft = min(headerWidth, indentDepth * colorIndicatorWidth);
      final dividerBounds = Rect.fromLTWH(
        dividerLeft,
        position,
        headerWidth - dividerLeft,
        dividerHeights[rowIndex],
      );
      nextDividers.add(
        TrackDividerLayout(
          resizedRowId: row.rowId,
          resizeEdge: resizeEdge,
          bounds: dividerBounds,
        ),
      );
      position = dividerBounds.bottom;
    }

    for (final (index, row) in rowsList.indexed) {
      if (index == sectionBreakIndex) {
        addSectionBreak();
      }

      if (row.isSendTrack) {
        addDivider(
          row: row,
          rowIndex: index,
          resizeEdge: TrackResizeEdge.top,
          indentDepth: row.trackDepth,
        );
      }

      final contentSpan = VerticalSpan(
        top: position,
        height: rowHeights[index],
      );
      final indicatorLeft = min(
        headerWidth,
        row.trackDepth * colorIndicatorWidth,
      );
      final headerLeft = row.rowKind == TrackRowKind.automationLane
          ? indicatorLeft
          : min(headerWidth, indicatorLeft + colorIndicatorWidth);
      nextRows.add(
        TrackRowLayout(
          rowIndex: index,
          row: row,
          contentSpan: contentSpan,
          headerBounds: Rect.fromLTWH(
            headerLeft,
            contentSpan.top,
            headerWidth - headerLeft,
            contentSpan.height,
          ),
        ),
      );
      position = contentSpan.bottom;

      if (!row.isSendTrack) {
        final nextRow = index + 1 < rowsList.length
            ? rowsList[index + 1]
            : null;
        final nextRegularRow = nextRow?.isSendTrack == false ? nextRow : null;
        addDivider(
          row: row,
          rowIndex: index,
          resizeEdge: TrackResizeEdge.bottom,
          indentDepth: nextRegularRow?.trackDepth ?? 0,
        );
      }
    }

    if (sectionBreakIndex == rowsList.length) {
      addSectionBreak();
    }

    final nextIndicators = <TrackColorIndicatorLayout>[];
    for (final (index, layout) in nextRows.indexed) {
      if (layout.row.rowKind == TrackRowKind.automationLane) continue;

      final rootDepth = layout.row.trackDepth;
      var lastDescendantIndex = index;
      while (lastDescendantIndex + 1 < nextRows.length &&
          nextRows[lastDescendantIndex + 1].row.trackDepth > rootDepth) {
        lastDescendantIndex++;
      }

      final indicatorLeft = min(headerWidth, rootDepth * colorIndicatorWidth);
      final indicatorRight = min(
        headerWidth,
        indicatorLeft + colorIndicatorWidth,
      );
      final lastDescendant = nextRows[lastDescendantIndex];
      final lastDescendantDivider = nextDividers[lastDescendantIndex];
      final indicatorBottom = switch (lastDescendantDivider.resizeEdge) {
        TrackResizeEdge.top => lastDescendant.contentSpan.bottom,
        TrackResizeEdge.bottom => lastDescendantDivider.bounds.bottom,
      };
      nextIndicators.add(
        TrackColorIndicatorLayout(
          rowId: layout.row.rowId,
          spansDescendants: lastDescendantIndex != index,
          bounds: Rect.fromLTRB(
            indicatorLeft,
            layout.contentSpan.top,
            indicatorRight,
            indicatorBottom,
          ),
        ),
      );
    }

    final nextTotalHeight = position;
    final layoutChanged =
        _headerWidth != headerWidth ||
        _viewportHeight != viewportHeight ||
        _contentHeight != nextTotalHeight ||
        _addTrackControlSpan != addTrackControlSpan ||
        _regularToSendGapSpan != regularToSendGapSpan ||
        !_rowLayoutEquality.equals(_rowLayouts, nextRows) ||
        !_indicatorLayoutEquality.equals(
          _colorIndicatorLayouts,
          nextIndicators,
        ) ||
        !_dividerLayoutEquality.equals(_dividerLayouts, nextDividers);

    _headerWidth = headerWidth;
    _viewportHeight = viewportHeight;
    _contentHeight = nextTotalHeight;
    _addTrackControlSpan = addTrackControlSpan;
    _regularToSendGapSpan = regularToSendGapSpan;
    _rowLayouts = List.unmodifiable(nextRows);
    _colorIndicatorLayouts = List.unmodifiable(nextIndicators);
    _dividerLayouts = List.unmodifiable(nextDividers);

    _rowIdToIndex.clear();
    _trackIdToIndex.clear();
    _trackIndexToId.clear();
    for (final layout in _rowLayouts) {
      _rowIdToIndex[layout.row.rowId] = layout.rowIndex;
      if (layout.row case ProjectTrackRow(:final trackId)) {
        _trackIdToIndex[trackId] = layout.rowIndex;
        _trackIndexToId[layout.rowIndex] = trackId;
      }
    }

    if (layoutChanged) {
      layoutRevision.value++;
    }
  }

  static void _validateNonNegativeFinite(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name, 'Must be finite and non-negative');
    }
  }

  static double _defaultDividerHeightFor(TrackDividerContext context) {
    return context.rowBelow?.rowKind == TrackRowKind.automationLane
        ? automationLaneDividerHeight
        : standardDividerHeight;
  }

  static void _validatePositiveFinite(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'Must be finite and positive');
    }
  }
}
