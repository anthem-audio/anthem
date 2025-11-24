/*
  Copyright (C) 2025 Joshua Wade

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

import 'dart:math';
import 'dart:typed_data';

import 'package:anthem/engine_api/engine.dart';
import 'package:flutter/foundation.dart';

/// A high-performance store for invalidation ranges.
///
/// During editing, invalidation ranges are used to determine which parts of the
/// sequence need to be rebuilt in the engine. Each invalidation range is
/// represented by a start and an end time, and a given editor operation may
/// generate many invalidation ranges.
///
/// Naively, an set of invalidation ranges for a piano roll operation might
/// contain one range for each note being dragged; however, we want to collapse
/// this as much as possible. For example, if a changed note goes from 0 to 100
/// and another goes from 50 to 150, we want to collapse these into a single
/// range from 0 to 150.
///
/// This class is designed to collect invalidation ranges for a pointer event in
/// one of the editors. As an example, if the user is dragging hundreds of notes
/// in the piano roll, a naive way to calculate the invalidation ranges would be
/// to add a new item to a list for each note, and then collapse down the list
/// at the end of the drag operation. This class aims to provide similar
/// behavior, but with an order of magnitude improvement in performance.
class InvalidationRangeCollector {
  /// The size of the inner array, and the maximum number of ranges that can be
  /// represented by this collector.
  ///
  /// If more than this number of ranges are collected, the collector will merge
  /// the closest ranges as needed to fit within this size.
  ///
  /// A higher number gives more fidelity at the cost of worst-case performance.
  final int maxSize;

  /// The number of invalidation ranges currently stored.
  int get size => _size;
  int _size = 0;

  /// The inner array that stores the start and end times of the
  /// invalidation ranges.
  final TypedDataList<int> _array;

  TypedDataList<int> get rawData => _array;

  /// A high-performance store for invalidation ranges.
  ///
  /// Optimized to be written to hundreds of times per mouse event in a given
  /// edit operation, and for near-zero cost reads.
  InvalidationRangeCollector([this.maxSize = 64])
    // We add one extra slot at the end which will be used when inserting items
    // to a full list
    : _array = kIsWeb && !kIsWasm
          // Non-wasm web builds don't support 64-bit integer lists. In the
          // future we need to convert all our time to double, which will remove
          // this hack.
          ? Int32List(maxSize * 2 + 2)
          : Int64List(maxSize * 2 + 2) {
    reset();
  }

  /// Resets the collector, clearing all stored invalidation ranges.
  void reset() {
    _size = 0;
    for (var i = 0; i < _array.length; i++) {
      _array[i] = -1; // Reset to -1 to indicate unused slots
    }
  }

  /// Adds a new invalidation range to the collector.
  void addRange(int start, int end) {
    assert(end > start);
    assert(start >= 0);
    assert(end > 0);

    if (size == 0) {
      _array[0] = start;
      _array[1] = end;
      _size = 1;
      return;
    }

    // Try merging with an existing range

    for (var i = 0; i < size; i++) {
      var existingRangeStart = _array[i * 2];
      var existingRangeEnd = _array[i * 2 + 1];

      // If the incoming range is fully within an existing range, then we
      // don't need to do anything.
      if (start >= existingRangeStart &&
          start <= existingRangeEnd &&
          end >= existingRangeStart &&
          end <= existingRangeEnd) {
        return;
      }

      // Check if the incoming range overlaps or totally covers this one
      if (start <= existingRangeEnd && end >= existingRangeStart) {
        _array[i * 2] = min(existingRangeStart, start);
        _array[i * 2 + 1] = max(existingRangeEnd, end);

        // Now that we've modified a range, it may overlap any number of
        // neighboring ranges, so we need to coalesce

        // Coalesce backwards
        for (var j = i - 1; j >= 0; j--) {
          // If the new start for the modified region has moved before the end
          // of the region we are checking, we can collapse the checked region
          // into the newly modified region.
          if (_array[i * 2] <= _array[j * 2 + 1]) {
            // Set i start to the minimum of i start and j start
            _array[i * 2] = min(_array[i * 2], _array[j * 2]);

            // Remove j
            _array[j * 2] = -1;
            _array[j * 2 + 1] = -1;
            _size--;
          } else {
            // The regions are sorted, so once we find a region that doesn't
            // overlap, none of the others will overlap either.
            break;
          }
        }

        // Coalesce forwards
        final originalSize = _size;
        for (var j = i + 1; j < originalSize; j++) {
          // If the new end for the modified region has moved after the start
          // of the region we are checking, we can collapse the checked region
          // into the newly modified region.
          if (_array[i * 2 + 1] >= _array[j * 2]) {
            // Set i end to the maximum of i end and j end
            _array[i * 2 + 1] = max(_array[i * 2 + 1], _array[j * 2 + 1]);

            // Remove j
            _array[j * 2] = -1;
            _array[j * 2 + 1] = -1;
            _size--;
          }
        }

        // Remove any blank spaces from the array
        _coalesceBlankSpaces();

        return;
      }
    }

    // If there is no overlap, then we need to insert the new range.
    _insertRange(start, end);
  }

  /// Get the stored ranges as a list of [InvalidationRange].
  List<InvalidationRange> getRanges() {
    List<InvalidationRange> result = [];

    for (var i = 0; i < size; i++) {
      result.add(
        InvalidationRange(start: _array[i * 2], end: _array[i * 2 + 1]),
      );
    }

    return result;
  }

  /// Tests if the given range overlaps any existing ranges.
  bool overlapsRange(int start, int end, [bool inclusive = true]) {
    for (var i = 0; i < size; i++) {
      var existingRangeStart = _array[i * 2];
      var existingRangeEnd = _array[i * 2 + 1];

      final inclusiveTest =
          start <= existingRangeEnd && end >= existingRangeStart;
      final exclusiveTest =
          start < existingRangeEnd && end > existingRangeStart;

      // Check if the incoming range overlaps or totally covers this one
      if ((inclusive && inclusiveTest) || (!inclusive && exclusiveTest)) {
        return true;
      } else if (end < existingRangeStart) {
        // Since the ranges are sorted, if we've reached a range that starts
        // after the end of the incoming range, we can stop checking.
        break;
      }
    }

    return false;
  }

  /// Collapses any blank spaces.
  ///
  /// For example, if the array looks like:
  /// [100, 200, -1, -1, 300, 400, -1, -1, 500, 600]
  ///
  /// After this function runs it will look like:
  /// [100, 200, 300, 400, 500, 600, -1, -1, -1, -1]
  void _coalesceBlankSpaces() {
    int readPtr = 0;
    int writePtr = 0;

    while (readPtr < _array.length) {
      if (_array[readPtr] == -1) {
        readPtr++;
        continue;
      }

      if (readPtr == writePtr) {
        readPtr++;
        writePtr++;
        continue;
      }

      _array[writePtr] = _array[readPtr];
      _array[readPtr] = -1;
      readPtr++;
      writePtr++;
    }
  }

  /// Insert the given range into the list.
  ///
  /// This assumes that the range does not overlap any existing ranges.
  void _insertRange(int start, int end) {
    // Try to insert in the middle
    for (int i = 0; i < _size; i++) {
      if (end < _array[i * 2]) {
        _moveBack(i);
        _array[i * 2] = start;
        _array[i * 2 + 1] = end;
        _size++;

        // If the array is full, free one space
        if (_size * 2 == _array.length) {
          _combineNearestPair();
        }

        return; // insert complete
      }
    }

    // If we couldn't insert in the middle, we will add it to the end.
    //
    // Note that the size must always be at most one less than the number of
    // spaces available in the array. If we ever fill up the array, we need to
    // free at least one item, which we will check for below.
    _array[_size * 2] = start;
    _array[_size * 2 + 1] = end;
    _size++;

    // If the array is full, free one space
    if (_size * 2 == _array.length) {
      _combineNearestPair();
    }
  }

  /// Moves the given index back, along with everything after it.
  ///
  /// Removes the last item in the list. Note that index is range index, not
  /// array index.
  void _moveBack(int index) {
    for (var i = _array.length - 1; i >= (index + 1) * 2; i -= 2) {
      _array[i] = _array[i - 2];
      _array[i - 1] = _array[i - 3];
    }

    _array[index * 2] = -1;
    _array[index * 2 + 1] = -1;
  }

  /// Combines the closest two ranges together.
  void _combineNearestPair() {
    if (_size < 2) return;

    var closestPairStartIndex = 0;
    var closestDistance = _array[2] - _array[1];

    for (var i = 1; i < _size - 1; i++) {
      var distance = _array[(i + 1) * 2] - _array[i * 2 + 1];
      if (distance < closestDistance) {
        closestDistance = distance;
        closestPairStartIndex = i;
      }
    }

    // Set the end of the first pair to the end of the second, which will
    // combine them
    _array[closestPairStartIndex * 2 + 1] =
        _array[((closestPairStartIndex + 1) * 2) + 1];

    // Zero out the second pair
    _array[(closestPairStartIndex + 1) * 2] = -1;
    _array[(closestPairStartIndex + 1) * 2 + 1] = -1;
    _size--;

    // Coalesce if needed
    _coalesceBlankSpaces();
  }
}
