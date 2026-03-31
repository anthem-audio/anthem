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

import 'package:anthem/widgets/editors/arranger/controller/state_machine/arranger_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

DivisionChange _divisionChange({required int offset, required int snapSize}) {
  return DivisionChange(
    offset: offset,
    divisionRenderSize: snapSize,
    divisionSnapSize: snapSize,
    distanceBetween: 1,
    startLabel: 1,
  );
}

void main() {
  group('getSnappedDragDelta', () {
    test('returns zero when start and current times are equal', () {
      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 100,
          divisionChanges: [_divisionChange(offset: 0, snapSize: 8)],
        ),
        0,
      );
    });

    test('uses half-snap threshold and full intervals for positive deltas', () {
      final divisions = [_divisionChange(offset: 0, snapSize: 8)];

      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 103,
          divisionChanges: divisions,
        ),
        0,
      );
      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 104,
          divisionChanges: divisions,
        ),
        8,
      );
      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 111,
          divisionChanges: divisions,
        ),
        8,
      );
      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 112,
          divisionChanges: divisions,
        ),
        16,
      );
    });

    test('uses half-snap threshold and full intervals for negative deltas', () {
      final divisions = [_divisionChange(offset: 0, snapSize: 8)];

      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 97,
          divisionChanges: divisions,
        ),
        0,
      );
      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 96,
          divisionChanges: divisions,
        ),
        -8,
      );
      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 89,
          divisionChanges: divisions,
        ),
        -8,
      );
      expect(
        getSnappedDragDelta(
          startTime: 100,
          currentTime: 88,
          divisionChanges: divisions,
        ),
        -16,
      );
    });

    test(
      'crosses forward division boundaries using absolute-time snap sizes',
      () {
        final divisions = [
          _divisionChange(offset: 0, snapSize: 8),
          _divisionChange(offset: 24, snapSize: 4),
        ];

        expect(
          getSnappedDragDelta(
            startTime: 20,
            currentTime: 24,
            divisionChanges: divisions,
          ),
          8,
        );
        expect(
          getSnappedDragDelta(
            startTime: 20,
            currentTime: 29,
            divisionChanges: divisions,
          ),
          8,
        );
        expect(
          getSnappedDragDelta(
            startTime: 20,
            currentTime: 30,
            divisionChanges: divisions,
          ),
          12,
        );
      },
    );

    test(
      'crosses backward division boundaries using absolute-time snap sizes',
      () {
        final divisions = [
          _divisionChange(offset: 0, snapSize: 8),
          _divisionChange(offset: 16, snapSize: 4),
        ];

        expect(
          getSnappedDragDelta(
            startTime: 20,
            currentTime: 19,
            divisionChanges: divisions,
          ),
          0,
        );
        expect(
          getSnappedDragDelta(
            startTime: 20,
            currentTime: 18,
            divisionChanges: divisions,
          ),
          -4,
        );
        expect(
          getSnappedDragDelta(
            startTime: 20,
            currentTime: 12,
            divisionChanges: divisions,
          ),
          -12,
        );
      },
    );

    test('falls back to unit snap when there are no division changes', () {
      expect(
        getSnappedDragDelta(
          startTime: 50,
          currentTime: 51,
          divisionChanges: const [],
        ),
        1,
      );
      expect(
        getSnappedDragDelta(
          startTime: 50,
          currentTime: 49,
          divisionChanges: const [],
        ),
        -1,
      );
    });
  });
}
