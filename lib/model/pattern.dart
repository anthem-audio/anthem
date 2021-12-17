/*
  Copyright (C) 2021 Joshua Wade

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

import 'package:anthem/helpers/get_id.dart';
import 'package:anthem/model/time_signature.dart';

import 'note.dart';

class PatternModel {
  int id;
  String name;
  Map<int, List<NoteModel>> notes;
  List<TimeSignatureChangeModel> timeSignatureChanges;
  TimeSignatureModel defaultTimeSignature; // TODO: Just pull from project??

  PatternModel()
      : id = getID(),
        name = "Pattern 123",
        notes = {},
        timeSignatureChanges = [],
        defaultTimeSignature = TimeSignatureModel(4, 4);
}
