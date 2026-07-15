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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new sequencers contain one arrangement selected for transport', () {
    final sequence = SequencerModel(
      idAllocator: ProjectEntityIdAllocator.test(getId),
    );

    expect(sequence.arrangement.name, 'Arrangement 1');
    expect(sequence.activeTransportSequenceID, sequence.arrangement.id);
  });

  test('serializes and loads a singular arrangement', () {
    final sequence = SequencerModel(
      idAllocator: ProjectEntityIdAllocator.test(getId),
    );
    final json = sequence.toJson();

    expect(json, contains('arrangement'));
    expect(json, isNot(contains('arrangements')));
    expect(json, isNot(contains('arrangementOrder')));
    expect(json, isNot(contains('activeArrangementID')));

    final loaded = SequencerModel.fromJson(json);

    expect(loaded.arrangement.id, sequence.arrangement.id);
    expect(loaded.arrangement.name, sequence.arrangement.name);
    expect(loaded.activeTransportSequenceID, loaded.arrangement.id);
  });
}
