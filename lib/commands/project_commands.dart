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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/processing_graph/processor.dart';
import 'package:anthem/model/project.dart';

import 'command.dart';

Future<void> _removeGenerator(ProjectModel project, ID generatorID) async {
  final generator = project.generators[generatorID];

  project.generatorList.removeWhere((element) => element == generatorID);
  if (project.generators.containsKey(generatorID)) {
    project.generators.remove(generatorID);
  }

  if (generator != null &&
      generator.generatorType == GeneratorType.instrument &&
      generator.processor.idInEngine != null) {
    await project.engine.processingGraphApi
        .removeProcessor(generator.processor.idInEngine!);
    await project.engine.processingGraphApi.compile();
  }
}

class AddGeneratorCommand extends Command {
  ID generatorId;
  String? processorId;
  String name;
  GeneratorType generatorType;
  Color color;

  AddGeneratorCommand({
    required this.generatorId,
    required this.processorId,
    required this.name,
    required this.generatorType,
    required this.color,
  });

  @override
  void execute(ProjectModel project) async {
    final processor = ProcessorModel(processorKey: processorId);
    final generator = GeneratorModel.create(
      id: generatorId,
      name: name,
      generatorType: generatorType,
      color: color,
      processor: processor,
      project: project,
    );

    if (generatorType == GeneratorType.instrument) {
      await generator.createInEngine(project.engine);
      await project.engine.processingGraphApi.compile();
    }

    project.generatorList.add(generatorId);
    project.generators[generatorId] = generator;
  }

  @override
  void rollback(ProjectModel project) {
    _removeGenerator(project, generatorId);
  }
}

class RemoveGeneratorCommand extends Command {
  GeneratorModel generator;
  late int index;

  RemoveGeneratorCommand({
    required ProjectModel project,
    required this.generator,
  }) {
    index = project.generatorList.indexOf(generator.id);
  }

  @override
  void execute(ProjectModel project) {
    _removeGenerator(project, generator.id);
  }

  @override
  void rollback(ProjectModel project) async {
    project.generators[generator.id] = generator;
    project.generatorList.insert(index, generator.id);

    if (generator.generatorType == GeneratorType.instrument) {
      await generator.createInEngine(project.engine);
      await project.engine.processingGraphApi.compile();
    }
  }
}
