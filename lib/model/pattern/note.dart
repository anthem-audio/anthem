/*
  Copyright (C) 2021 - 2024 Joshua Wade

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
import 'package:anthem_codegen/annotations.dart';
import 'package:mobx/mobx.dart';

part 'note.g.dart';

@AnthemModel.all()
class NoteModel extends _NoteModel
    with _$NoteModel, _$NoteModelAnthemModelMixin {
  NoteModel({
    required super.key,
    required super.velocity,
    required super.length,
    required super.offset,
    required super.pan,
  });

  NoteModel.uninitialized()
      : super(key: 0, velocity: 0, length: 0, offset: 0, pan: 0);

  NoteModel.fromNoteModel(NoteModel model)
      : super(
          key: model.key,
          length: model.length,
          offset: model.offset,
          velocity: model.velocity,
          pan: model.pan,
        );

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelAnthemModelMixin.fromJson(json);
}

abstract class _NoteModel with Store {
  String id;

  @observable
  int key;

  @observable
  int velocity;

  @observable
  int length;

  @observable
  int offset;

  @observable
  int pan;

  _NoteModel({
    required this.key,
    required this.velocity,
    required this.length,
    required this.offset,
    required this.pan,
  }) : id = getID();
}
