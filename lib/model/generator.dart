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

import 'dart:ui';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/generated/project_generated.dart';
import 'package:anthem/helpers/convert.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/hydratable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

import 'processing_graph/processor.dart';

part 'generator.g.dart';

// Note: I'm not sure about how we're differentiating generator types here. This
// deals with the actual audio engine side of things which is not sketched out.
// For now, we're just marking each generator with an enum saying what kind it
// is, and we can rethink later.

enum GeneratorType { instrument, automation }

@JsonSerializable()
class GeneratorModel extends _GeneratorModel with _$GeneratorModel {
  GeneratorModel({
    required String id,
    required String name,
    required GeneratorType generatorType,
    required Color color,
    required ProcessorModel processor,
  }) : super(
          id: id,
          name: name,
          generatorType: generatorType,
          color: color,
          processor: processor,
        );

  GeneratorModel.create({
    required String id,
    required String name,
    required GeneratorType generatorType,
    required Color color,
    required ProcessorModel processor,
    required ProjectModel project,
  }) : super.create(
          id: id,
          name: name,
          generatorType: generatorType,
          color: color,
          processor: processor,
          project: project,
        );

  factory GeneratorModel.fromJson(Map<String, dynamic> json) =>
      _$GeneratorModelFromJson(json);
}

abstract class _GeneratorModel extends Hydratable with Store {
  String id;

  @observable
  String name;

  @observable
  GeneratorType generatorType;

  @JsonKey(toJson: ColorConvert.colorToInt, fromJson: ColorConvert.intToColor)
  @observable
  Color color;

  @observable
  ProcessorModel processor;

  @JsonKey(includeFromJson: false, includeToJson: false)
  ProjectModel? _project;

  _GeneratorModel({
    required this.id,
    required this.name,
    required this.generatorType,
    required this.color,
    required this.processor,
  });

  _GeneratorModel.create({
    required this.id,
    required this.name,
    required this.generatorType,
    required this.color,
    required this.processor,
    required ProjectModel project,
  }) : super() {
    hydrate(project: project);
  }

  Map<String, dynamic> toJson() =>
      _$GeneratorModelToJson(this as GeneratorModel);

  void hydrate({
    required ProjectModel project,
  }) {
    _project = project;
    isHydrated = true;
  }

  Future<void> createInEngine(Engine engine) async {
    await processor.createInEngine(engine);

    await engine.processingGraphApi.connectProcessors(
      connectionType: ProcessorConnectionType.Audio,
      sourceId: processor.idInEngine!,
      sourcePortIndex: 0,
      destinationId: _project!.masterOutputNodeId!,
      destinationPortIndex: 0,
    );
  }
}
