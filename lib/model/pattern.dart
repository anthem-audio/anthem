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

import 'dart:collection';
import 'dart:convert';

import 'package:anthem/helpers/get_id.dart';
import 'package:anthem/model/time_signature.dart';
import 'package:json_annotation/json_annotation.dart';

import 'note.dart';

part 'pattern.g.dart';

@JsonSerializable()
class PatternModel {
  int id;
  String name;
  Map<int, List<NoteModel>> notes;
  List<TimeSignatureChangeModel> timeSignatureChanges;
  TimeSignatureModel defaultTimeSignature; // TODO: Just pull from project??

  PatternModel(this.name)
      : id = getID(),
        notes = HashMap(),
        timeSignatureChanges = [],
        defaultTimeSignature = TimeSignatureModel(4, 4);

  factory PatternModel.fromJson(Map<String, dynamic> json) =>
      _$PatternModelFromJson(json);

  Map<String, dynamic> toJson() => _$PatternModelToJson(this);

  @override
  String toString() => json.encode(toJson());

  @override
  operator ==(Object other) {
    if (identical(other, this)) return true;

    return other is PatternModel &&
        other.id == id &&
        other.name == name &&
        other.notes == notes &&
        other.timeSignatureChanges == timeSignatureChanges &&
        other.defaultTimeSignature == defaultTimeSignature;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      notes.hashCode ^
      timeSignatureChanges.hashCode ^
      defaultTimeSignature.hashCode;
}
