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
import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockProjectModel extends Mock implements ProjectModel {
  MockProjectModel(this._sequence);

  final SequencerModel _sequence;

  @override
  SequencerModel get sequence => _sequence;
}

void main() {
  late MockProjectModel project;
  late SequencerModel sequence;
  late AnthemObservableMap<Id, ArrangementModel> arrangements;
  late AnthemObservableList<Id> arrangementOrder;

  ArrangementModel addArrangementToProject(String name) {
    final arrangement = ArrangementModel.create(name: name, id: getId());
    arrangements[arrangement.id] = arrangement;
    arrangementOrder.add(arrangement.id);
    return arrangement;
  }

  ClipModel createClip({int offset = 0, TimeViewModel? timeView}) {
    return ClipModel.create(
      patternId: getId(),
      trackId: getId(),
      offset: offset,
      timeView: timeView,
    );
  }

  setUp(() {
    sequence = SequencerModel.uninitialized();
    arrangements = AnthemObservableMap();
    arrangementOrder = AnthemObservableList();

    sequence.arrangements = arrangements;
    sequence.arrangementOrder = arrangementOrder;
    project = MockProjectModel(sequence);
  });

  group('ClipAddRemoveCommand', () {
    test('add execute and rollback', () {
      final arrangement = addArrangementToProject('Arrangement 1');
      final clip = createClip(offset: 128);
      final command = ClipAddRemoveCommand.add(
        arrangementID: arrangement.id,
        clip: clip,
      );

      command.execute(project);
      expect(arrangement.clips[clip.id], same(clip));

      command.rollback(project);
      expect(arrangement.clips[clip.id], isNull);
    });

    test('remove execute and rollback', () {
      final arrangement = addArrangementToProject('Arrangement 1');
      final clip = createClip(offset: 128);
      arrangement.clips[clip.id] = clip;

      final command = ClipAddRemoveCommand.remove(
        project: project,
        arrangementID: arrangement.id,
        clipId: clip.id,
      );

      command.execute(project);
      expect(arrangement.clips[clip.id], isNull);

      command.rollback(project);
      expect(arrangement.clips[clip.id], same(clip));
    });

    test('add throws when arrangement does not exist', () {
      final clip = createClip();
      final command = ClipAddRemoveCommand.add(
        arrangementID: getId(),
        clip: clip,
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });

    test('add throws when clip already exists', () {
      final arrangement = addArrangementToProject('Arrangement 1');
      final clip = createClip();
      arrangement.clips[clip.id] = clip;

      final command = ClipAddRemoveCommand.add(
        arrangementID: arrangement.id,
        clip: clip,
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });

    test('remove constructor throws when arrangement does not exist', () {
      expect(
        () => ClipAddRemoveCommand.remove(
          project: project,
          arrangementID: getId(),
          clipId: getId(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('remove constructor throws when clip does not exist', () {
      final arrangement = addArrangementToProject('Arrangement 1');

      expect(
        () => ClipAddRemoveCommand.remove(
          project: project,
          arrangementID: arrangement.id,
          clipId: getId(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('remove execute throws if clip was removed before execute', () {
      final arrangement = addArrangementToProject('Arrangement 1');
      final clip = createClip();
      arrangement.clips[clip.id] = clip;

      final command = ClipAddRemoveCommand.remove(
        project: project,
        arrangementID: arrangement.id,
        clipId: clip.id,
      );

      arrangement.clips.remove(clip.id);

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });
  });

  group('Arrangement commands', () {
    test('AddArrangementCommand execute and rollback', () {
      final command = AddArrangementCommand(
        project: project,
        arrangementName: 'New Arrangement',
      );

      command.execute(project);

      expect(arrangements[command.arrangementID], isNotNull);
      expect(arrangementOrder.last, equals(command.arrangementID));

      command.rollback(project);

      expect(arrangements[command.arrangementID], isNull);
      expect(arrangementOrder.contains(command.arrangementID), isFalse);
    });

    test('DeleteArrangementCommand execute and rollback preserves index', () {
      final arrangementA = addArrangementToProject('A');
      final arrangementB = addArrangementToProject('B');
      final arrangementC = addArrangementToProject('C');

      final command = DeleteArrangementCommand(
        project: project,
        arrangement: arrangementB,
      );

      command.execute(project);

      expect(arrangements[arrangementB.id], isNull);
      expect(arrangementOrder, equals([arrangementA.id, arrangementC.id]));

      command.rollback(project);

      expect(arrangements[arrangementB.id], same(arrangementB));
      expect(
        arrangementOrder,
        equals([arrangementA.id, arrangementB.id, arrangementC.id]),
      );
    });

    test('SetArrangementNameCommand execute and rollback', () {
      final arrangement = addArrangementToProject('Old Name');
      final command = SetArrangementNameCommand(
        project: project,
        arrangementID: arrangement.id,
        newName: 'New Name',
      );

      command.execute(project);
      expect(arrangement.name, equals('New Name'));

      command.rollback(project);
      expect(arrangement.name, equals('Old Name'));
    });
  });

  group('Clip edit commands', () {
    test('MoveClipsCommand execute and rollback', () {
      final arrangement = addArrangementToProject('Arrangement 1');
      final firstTrack = getId();
      final secondTrack = getId();
      final firstClip = ClipModel.create(
        patternId: getId(),
        trackId: firstTrack,
        offset: 64,
      );
      final secondClip = ClipModel.create(
        patternId: getId(),
        trackId: secondTrack,
        offset: 80,
      );
      arrangement.clips[firstClip.id] = firstClip;
      arrangement.clips[secondClip.id] = secondClip;

      final command = MoveClipsCommand(
        arrangementID: arrangement.id,
        clipMoves: [
          (clipID: firstClip.id, oldOffset: 64, newOffset: 128),
          (clipID: secondClip.id, oldOffset: 80, newOffset: 144),
        ],
      );

      command.execute(project);
      expect(firstClip.offset, equals(128));
      expect(secondClip.offset, equals(144));
      expect(firstClip.trackId, equals(firstTrack));
      expect(secondClip.trackId, equals(secondTrack));

      command.rollback(project);
      expect(firstClip.offset, equals(64));
      expect(secondClip.offset, equals(80));
      expect(firstClip.trackId, equals(firstTrack));
      expect(secondClip.trackId, equals(secondTrack));
    });

    test('ResizeClipCommand execute and rollback with non-null time view', () {
      final arrangement = addArrangementToProject('Arrangement 1');
      final oldTimeView = TimeViewModel(start: 0, end: 96);
      final newTimeView = TimeViewModel(start: 16, end: 64);
      final clip = createClip(offset: 32, timeView: oldTimeView);
      arrangement.clips[clip.id] = clip;

      final command = ResizeClipCommand(
        arrangementID: arrangement.id,
        clipID: clip.id,
        oldOffset: 32,
        oldTimeView: oldTimeView,
        newOffset: 96,
        newTimeView: newTimeView,
      );

      command.execute(project);
      expect(clip.offset, equals(96));
      expect(clip.timeView, same(newTimeView));

      command.rollback(project);
      expect(clip.offset, equals(32));
      expect(clip.timeView, same(oldTimeView));
    });

    test('ResizeClipCommand rollback restores null time view', () {
      final arrangement = addArrangementToProject('Arrangement 1');
      final newTimeView = TimeViewModel(start: 16, end: 64);
      final clip = createClip(offset: 8, timeView: null);
      arrangement.clips[clip.id] = clip;

      final command = ResizeClipCommand(
        arrangementID: arrangement.id,
        clipID: clip.id,
        oldOffset: 8,
        oldTimeView: null,
        newOffset: 24,
        newTimeView: newTimeView,
      );

      command.execute(project);
      expect(clip.offset, equals(24));
      expect(clip.timeView, same(newTimeView));

      command.rollback(project);
      expect(clip.offset, equals(8));
      expect(clip.timeView, isNull);
    });
  });
}
