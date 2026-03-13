/*
  Copyright (C) 2021 - 2026 Joshua Wade

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
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'note.g.dart';

/// The actual attributes of a note to use when rendering.
///
/// When a user performs a note edit, such as dragging a note, the model is not
/// mutated right away. This prevents the engine from receiving excess messages
/// during bulk edits of hundreds or thousands of notes. The uncompressed volume
/// of these messages can be surprisingly large - back-of-the-envelope math
/// gives hundreds of megabytes per second in some extreme worst-case scenarios.
///
/// However, we do want the editor to be responsive. Patterns store notes, but
/// they also store:
/// - Note overrides, which temporarily modify note parameters like offset and
///   length
/// - Preview notes, which are new notes that have not actually been added to
///   the model yet
///
/// This class serves as a way to communicate the resolved render attributes of
/// a given note to downstream consumers that want to render notes. These
/// consumers include:
/// - The main piano roll note area
/// - The piano roll attribute editor
/// - Clips, which render a preview of the notes contained in their associated
///   pattern
class ResolvedPatternNote {
  final Id id;
  final int key;
  final double velocity;
  final int length;
  final int offset;
  final double pan;
  final bool hasOverride;
  final bool isPreviewOnly;

  const ResolvedPatternNote({
    required this.id,
    required this.key,
    required this.velocity,
    required this.length,
    required this.offset,
    required this.pan,
    required this.hasOverride,
    required this.isPreviewOnly,
  });
}

@AnthemModel.syncedModel()
class NoteModel extends _NoteModel
    with _$NoteModel, _$NoteModelAnthemModelMixin {
  NoteModel({
    required ProjectEntityIdAllocator idAllocator,
    required super.key,
    required super.velocity,
    required super.length,
    required super.offset,
    required super.pan,
  }) : super(id: idAllocator.allocateId());

  NoteModel.uninitialized()
    : super(id: '', key: 0, velocity: 0, length: 0, offset: 0, pan: 0);

  NoteModel.fromNoteModel(NoteModel model)
    : super(
        id: model.id,
        key: model.key,
        length: model.length,
        offset: model.offset,
        velocity: model.velocity,
        pan: model.pan,
      );

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelAnthemModelMixin.fromJson(json);
}

abstract class _NoteModel with Store, AnthemModelBase, ProjectModelGetterMixin {
  Id id;

  @anthemObservable
  int key;

  @anthemObservable
  double velocity;

  @anthemObservable
  int length;

  @anthemObservable
  int offset;

  @anthemObservable
  double pan;

  _NoteModel({
    required this.id,
    required this.key,
    required this.velocity,
    required this.length,
    required this.offset,
    required this.pan,
  });
}

@AnthemModel(serializable: true, generateModelSync: true)
class PatternNoteOverrideModel extends _PatternNoteOverrideModel
    with
        _$PatternNoteOverrideModel,
        _$PatternNoteOverrideModelAnthemModelMixin {
  PatternNoteOverrideModel({
    super.key,
    super.velocity,
    super.length,
    super.offset,
    super.pan,
  });

  PatternNoteOverrideModel.uninitialized() : super();

  factory PatternNoteOverrideModel.fromJson(Map<String, dynamic> json) =>
      _$PatternNoteOverrideModelAnthemModelMixin.fromJson(json);
}

abstract class _PatternNoteOverrideModel with Store, AnthemModelBase {
  @anthemObservable
  int? key;

  @anthemObservable
  double? velocity;

  @anthemObservable
  int? length;

  @anthemObservable
  int? offset;

  @anthemObservable
  double? pan;

  _PatternNoteOverrideModel({
    this.key,
    this.velocity,
    this.length,
    this.offset,
    this.pan,
  });

  bool get hasAnyValue =>
      key != null ||
      velocity != null ||
      length != null ||
      offset != null ||
      pan != null;
}
