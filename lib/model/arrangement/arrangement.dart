/*
  Copyright (C) 2022 - 2024 Joshua Wade

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

import 'dart:math';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/hydratable.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem_codegen/annotations.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

import 'clip.dart';

part 'arrangement.g.dart';

@JsonSerializable()
@AnthemModel(serializable: true)
class ArrangementModel extends _ArrangementModel
    with _$ArrangementModel, _$ArrangementModelAnthemModelMixin {
  ArrangementModel({required super.name, required super.id});

  ArrangementModel.uninitialized() : super(name: '', id: '');

  ArrangementModel.create(
      {required super.name, required super.id, required super.project})
      : super.create();

  factory ArrangementModel.fromJson(Map<String, dynamic> json) =>
      _$ArrangementModelFromJson(json);

  factory ArrangementModel.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$ArrangementModelAnthemModelMixin.fromJson_ANTHEM(json);
}

abstract class _ArrangementModel extends Hydratable with Store {
  ID id;

  @observable
  String name;

  @observable
  @JsonKey(fromJson: _clipsFromJson, toJson: _clipsToJson)
  ObservableMap<ID, ClipModel> clips = ObservableMap();

  @observable
  TimeSignatureModel defaultTimeSignature = TimeSignatureModel(4, 4);

  @JsonKey(includeFromJson: false, includeToJson: false)
  @Hide.all()
  ProjectModel? _project;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @Hide(serialization: true)
  late int editPointer;

  ProjectModel get project {
    return _project!;
  }

  _ArrangementModel({
    required this.name,
    required this.id,
  }) : super();

  _ArrangementModel.create({
    required this.name,
    required this.id,
    required ProjectModel project,
  }) : super() {
    hydrate(project: project);
  }

  Map<String, dynamic> toJson() =>
      _$ArrangementModelToJson(this as ArrangementModel);

  void hydrate({
    required ProjectModel project,
  }) {
    _project = project;
    isHydrated = true;
  }

  Future<void> createInEngine(Engine engine) async {
    // Creates a corresponding Tracktion `Edit` in the engine
    editPointer = await project.engine.projectApi.addArrangement();
  }

  void deleteInEngine(Engine engine) {
    // Deletes the edit in the engine
    project.engine.projectApi.deleteArrangement(editPointer);
  }

  /// Gets the time position of the end of the last clip in this arrangement,
  /// rounded upward to the nearest `barMultiple` bars.
  int getWidth({
    int barMultiple = 4,
    int minPaddingInBarMultiples = 4,
  }) {
    final ticksPerBar = project.song.ticksPerQuarter ~/
        (defaultTimeSignature.denominator ~/ 4) *
        defaultTimeSignature.numerator;
    final lastContent = clips.values.fold<int>(
      ticksPerBar * barMultiple * minPaddingInBarMultiples,
      (previousValue, clip) =>
          max(previousValue, clip.offset + clip.getWidth(project)),
    );

    return (max(lastContent, 1) / (ticksPerBar * barMultiple)).ceil() *
        ticksPerBar *
        barMultiple;
  }

  @computed
  int get width => getWidth();
}

// JSON serialization and deserialization functions

ObservableMap<ID, ClipModel> _clipsFromJson(Map<String, dynamic> clips) {
  return ObservableMap.of(clips.map(
    (key, value) => MapEntry(key, ClipModel.fromJson(value)),
  ));
}

Map<String, dynamic> _clipsToJson(ObservableMap<ID, ClipModel> clips) {
  return clips.map(
    (key, value) => MapEntry(key, value.toJson()),
  );
}
