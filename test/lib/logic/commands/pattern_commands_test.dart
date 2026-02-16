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
import 'package:anthem/logic/commands/pattern_commands.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
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

  PatternModel createPattern(String name) {
    return PatternModel.create(name: name);
  }

  setUp(() {
    sequence = SequencerModel.uninitialized();
    patterns = AnthemObservableMap();
    sequence.patterns = patterns;
    project = MockProjectModel(sequence);
  });

  group('PatternAddRemoveCommand', () {
    test('add execute and rollback', () {
      final pattern = createPattern('Pattern 1');
      final command = PatternAddRemoveCommand.add(pattern: pattern);

      command.execute(project);
      expect(patterns[pattern.id], same(pattern));

      command.rollback(project);
      expect(patterns[pattern.id], isNull);
    });

    test('remove execute and rollback', () {
      final pattern = createPattern('Pattern 1');
      patterns[pattern.id] = pattern;

      final command = PatternAddRemoveCommand.remove(
        project: project,
        patternId: pattern.id,
      );

      command.execute(project);
      expect(patterns[pattern.id], isNull);

      command.rollback(project);
      expect(patterns[pattern.id], same(pattern));
    });

    test('add throws when pattern already exists', () {
      final pattern = createPattern('Pattern 1');
      patterns[pattern.id] = pattern;

      final command = PatternAddRemoveCommand.add(pattern: pattern);

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });

    test('remove constructor throws when pattern does not exist', () {
      final missingPatternId = getId();

      expect(
        () => PatternAddRemoveCommand.remove(
          project: project,
          patternId: missingPatternId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('remove execute throws if pattern was removed before execute', () {
      final pattern = createPattern('Pattern 1');
      patterns[pattern.id] = pattern;

      final command = PatternAddRemoveCommand.remove(
        project: project,
        patternId: pattern.id,
      );

      patterns.remove(pattern.id);

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });
  });

  group('SetPatternNameCommand', () {
    test('execute and rollback update name', () {
      final pattern = createPattern('Old Name');
      patterns[pattern.id] = pattern;

      final command = SetPatternNameCommand(
        project: project,
        patternID: pattern.id,
        newName: 'New Name',
      );

      command.execute(project);
      expect(pattern.name, equals('New Name'));

      command.rollback(project);
      expect(pattern.name, equals('Old Name'));
    });
  });

  group('SetPatternColorCommand', () {
    test('execute and rollback update color', () {
      final oldColor = AnthemColor(hue: 10, palette: .normal);
      final newColor = AnthemColor(hue: 120, palette: .bright);
      final pattern = createPattern('Pattern 1')..color = oldColor;
      patterns[pattern.id] = pattern;

      final command = SetPatternColorCommand(
        project: project,
        patternID: pattern.id,
        newColor: newColor,
      );

      command.execute(project);
      expect(pattern.color, same(newColor));

      command.rollback(project);
      expect(pattern.color, same(oldColor));
    });
  });
}
