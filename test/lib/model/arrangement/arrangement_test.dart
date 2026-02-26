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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:flutter_test/flutter_test.dart';

ClipModel _createClip({required Id id, required Id patternId, int offset = 0}) {
  return ClipModel.create(
    id: id,
    patternId: patternId,
    trackId: getId(),
    offset: offset,
  );
}

ArrangementModel _createArrangement() {
  final arrangement = ArrangementModel.create(name: 'A', id: getId());
  arrangement.setParentPropertiesOnChildren();
  return arrangement;
}

void main() {
  group('ArrangementModel pattern clip reference cache', () {
    test('is not serialized', () {
      final arrangement = _createArrangement();
      final serialized = arrangement.toJson();

      expect(serialized.containsKey('patternClipReferenceCounts'), isFalse);
    });

    test('is rebuilt from clips when deserialized', () {
      final patternA = getId();
      final patternB = getId();
      final clipA1 = _createClip(id: getId(), patternId: patternA, offset: 0);
      final clipA2 = _createClip(id: getId(), patternId: patternA, offset: 96);
      final clipB = _createClip(id: getId(), patternId: patternB, offset: 192);

      final arrangement = ArrangementModel.fromJson({
        'id': getId(),
        'name': 'Deserialized arrangement',
        'clips': {
          clipA1.id: clipA1.toJson(),
          clipA2.id: clipA2.toJson(),
          clipB.id: clipB.toJson(),
        },
        'timeSignatureChanges': <Map<String, dynamic>>[],
      });

      expect(arrangement.getPatternClipReferenceCount(patternA), equals(2));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
      expect(
        arrangement.patternClipReferenceCounts.keys.toSet(),
        equals({patternA, patternB}),
      );
    });

    test('updates on clip add and remove', () {
      final arrangement = _createArrangement();
      final patternA = getId();
      final patternB = getId();
      final clipA1 = _createClip(id: getId(), patternId: patternA);
      final clipA2 = _createClip(id: getId(), patternId: patternA);
      final clipB = _createClip(id: getId(), patternId: patternB);

      arrangement.clips[clipA1.id] = clipA1;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));

      arrangement.clips[clipA2.id] = clipA2;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(2));

      arrangement.clips[clipB.id] = clipB;
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));

      arrangement.clips.remove(clipA1.id);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));

      arrangement.clips.remove(clipA2.id);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(
        arrangement.patternClipReferenceCounts.containsKey(patternA),
        isFalse,
      );
    });

    test('updates correctly when map put replaces an existing clip', () {
      final arrangement = _createArrangement();
      final patternA = getId();
      final patternB = getId();
      final clipId = getId();

      arrangement.clips[clipId] = _createClip(id: clipId, patternId: patternA);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(0));

      arrangement.clips[clipId] = _createClip(id: clipId, patternId: patternB);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
    });

    test('updates when a clip patternId changes', () {
      final arrangement = _createArrangement();
      final patternA = getId();
      final patternB = getId();
      final clip1 = _createClip(id: getId(), patternId: patternA);
      final clip2 = _createClip(id: getId(), patternId: patternA);

      arrangement.clips[clip1.id] = clip1;
      arrangement.clips[clip2.id] = clip2;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(2));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(0));

      clip1.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));

      // Writing same value should not change counts.
      clip1.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));

      clip2.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(2));
      expect(
        arrangement.patternClipReferenceCounts.containsKey(patternA),
        isFalse,
      );
    });
  });
}
