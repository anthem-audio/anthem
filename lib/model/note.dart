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

class NoteModel {
  int id;
  int key;
  int velocity;
  int length;
  int offset;

  NoteModel({
    required this.key,
    required this.velocity,
    required this.length,
    required this.offset,
  }) : id = getID();

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;

    return other is NoteModel &&
        other.id == id &&
        other.key == key &&
        other.velocity == velocity &&
        other.length == length &&
        other.offset == offset;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      key.hashCode ^
      velocity.hashCode ^
      length.hashCode ^
      offset.hashCode;
}
