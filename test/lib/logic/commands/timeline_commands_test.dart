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
import 'package:anthem/logic/commands/timeline_commands.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/time_signature.dart';
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
  late AnthemObservableMap<Id, PatternModel> patterns;
  late AnthemObservableMap<Id, ArrangementModel> arrangements;
  late AnthemObservableList<Id> arrangementOrder;

  PatternModel addPatternToProject(String name) {
    final pattern = PatternModel.create(name: name);
    patterns[pattern.id] = pattern;
    return pattern;
  }

  ArrangementModel addArrangementToProject(String name) {
    final arrangement = ArrangementModel.create(name: name, id: getId());
    arrangements[arrangement.id] = arrangement;
    arrangementOrder.add(arrangement.id);
    return arrangement;
  }

  TimeSignatureChangeModel createChange({
    required int offset,
    required int numerator,
    required int denominator,
  }) {
    return TimeSignatureChangeModel(
      offset: offset,
      timeSignature: TimeSignatureModel(numerator, denominator),
    );
  }

  setUp(() {
    sequence = SequencerModel.uninitialized();
    patterns = AnthemObservableMap();
    arrangements = AnthemObservableMap();
    arrangementOrder = AnthemObservableList();

    sequence.patterns = patterns;
    sequence.arrangements = arrangements;
    sequence.arrangementOrder = arrangementOrder;

    project = MockProjectModel(sequence);
  });

  group('AddTimeSignatureChangeCommand', () {
    test('pattern execute and rollback', () {
      final pattern = addPatternToProject('Pattern');
      final existingChange = createChange(
        offset: 96,
        numerator: 4,
        denominator: 4,
      );
      pattern.timeSignatureChanges.add(existingChange);

      final newChange = createChange(offset: 48, numerator: 3, denominator: 4);
      final command = AddTimeSignatureChangeCommand(
        timelineKind: TimelineKind.pattern,
        patternID: pattern.id,
        change: newChange,
      );

      command.execute(project);
      expect(pattern.timeSignatureChanges.map((e) => e.offset), [48, 96]);

      command.rollback(project);
      expect(pattern.timeSignatureChanges.map((e) => e.offset), [96]);
    });

    test('arrangement execute and rollback', () {
      final arrangement = addArrangementToProject('Arrangement');
      final existingChange = createChange(
        offset: 96,
        numerator: 4,
        denominator: 4,
      );
      arrangement.timeSignatureChanges.add(existingChange);

      final newChange = createChange(offset: 48, numerator: 3, denominator: 4);
      final command = AddTimeSignatureChangeCommand(
        timelineKind: TimelineKind.arrangement,
        arrangementID: arrangement.id,
        change: newChange,
      );

      command.execute(project);
      expect(arrangement.timeSignatureChanges.map((e) => e.offset), [48, 96]);

      command.rollback(project);
      expect(arrangement.timeSignatureChanges.map((e) => e.offset), [96]);
    });
  });

  group('RemoveTimeSignatureChangeCommand', () {
    test('arrangement execute and rollback', () {
      final arrangement = addArrangementToProject('Arrangement');
      final first = createChange(offset: 48, numerator: 3, denominator: 4);
      final second = createChange(offset: 96, numerator: 4, denominator: 4);
      arrangement.timeSignatureChanges.addAll([first, second]);

      final command = RemoveTimeSignatureChangeCommand(
        timelineKind: TimelineKind.arrangement,
        project: project,
        arrangementID: arrangement.id,
        changeID: first.id,
      );

      command.execute(project);
      expect(arrangement.timeSignatureChanges.map((e) => e.id), [second.id]);

      command.rollback(project);
      expect(arrangement.timeSignatureChanges.map((e) => e.offset), [48, 96]);
    });
  });

  group('MoveTimeSignatureChangeCommand', () {
    test('arrangement execute and rollback', () {
      final arrangement = addArrangementToProject('Arrangement');
      final first = createChange(offset: 48, numerator: 3, denominator: 4);
      final second = createChange(offset: 96, numerator: 4, denominator: 4);
      arrangement.timeSignatureChanges.addAll([first, second]);

      final command = MoveTimeSignatureChangeCommand(
        project: project,
        timelineKind: TimelineKind.arrangement,
        arrangementID: arrangement.id,
        changeID: first.id,
        newOffset: 120,
      );

      command.execute(project);
      expect(arrangement.timeSignatureChanges.map((e) => e.offset), [96, 120]);

      command.rollback(project);
      expect(arrangement.timeSignatureChanges.map((e) => e.offset), [48, 96]);
    });
  });

  group('SetTimeSignature commands', () {
    test('numerator and denominator update for arrangement', () {
      final arrangement = addArrangementToProject('Arrangement');
      final change = createChange(offset: 64, numerator: 4, denominator: 4);
      arrangement.timeSignatureChanges.add(change);

      final setNumerator = SetTimeSignatureNumeratorCommand(
        project: project,
        arrangementID: arrangement.id,
        changeID: change.id,
        numerator: 7,
      );
      setNumerator.execute(project);
      expect(change.timeSignature.numerator, 7);
      setNumerator.rollback(project);
      expect(change.timeSignature.numerator, 4);

      final setDenominator = SetTimeSignatureDenominatorCommand(
        project: project,
        arrangementID: arrangement.id,
        changeID: change.id,
        denominator: 8,
      );
      setDenominator.execute(project);
      expect(change.timeSignature.denominator, 8);
      setDenominator.rollback(project);
      expect(change.timeSignature.denominator, 4);
    });
  });
}
