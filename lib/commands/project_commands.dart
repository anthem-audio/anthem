/*
  Copyright (C) 2021 - 2025 Joshua Wade

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
import 'package:anthem/model/model.dart';

import 'command.dart';

void _addGenerator(ProjectModel project, GeneratorModel generator,
    [int? index]) {
  if (index != null) {
    project.generatorList.insert(index, generator.id);
  } else {
    project.generatorList.add(generator.id);
  }
  project.generators[generator.id] = generator;

  // If the node has no processor, treat this as a dummy generator. We use this
  // for testing so we need this case.
  if (generator.plugin.processor == null) {
    return;
  }

  project.processingGraph.addNode(generator.plugin);
  project.processingGraph.addConnection(
    NodeConnectionModel(
      id: getId(),
      sourceNodeId: generator.plugin.id,
      sourcePortId: generator.plugin.audioOutputPorts[0].id,
      destinationNodeId: project.processingGraph.masterOutputNodeId,
      destinationPortId:
          project.processingGraph.getMasterOutputNode().audioInputPorts[0].id,
    ),
  );

  project.engine.processingGraphApi.compile();
}

void _removeGenerator(ProjectModel project, Id generatorID) {
  GeneratorModel? generator;

  project.generatorList.removeWhere((element) => element == generatorID);
  if (project.generators.containsKey(generatorID)) {
    generator = project.generators.remove(generatorID);
  }

  if (generator == null || generator.plugin.processor == null) {
    return;
  }

  project.processingGraph.removeNode(generator.plugin.id);

  project.engine.processingGraphApi.compile();
}

class AddGeneratorCommand extends Command {
  Id generatorId;

  /// A node which holds the plugin for the generator.
  ///
  /// Typically this would be created with the `createNode()` method of the
  /// processor model, e.g.:
  ///
  /// ```dart
  /// final node = ToneGeneratorProcessorModel.createNode();
  /// ```
  NodeModel node;

  /// The human-readable name of the generator.
  String name;

  /// The type of generator to add.
  GeneratorType generatorType;

  /// The color to use for the generator.
  Color color;

  AddGeneratorCommand({
    required this.generatorId,
    required this.node,
    required this.name,
    required this.generatorType,
    required this.color,
  });

  @override
  void execute(ProjectModel project) {
    final generator = GeneratorModel(
      id: generatorId,
      name: name,
      generatorType: generatorType,
      color: color,
      plugin: node,
    );

    _addGenerator(project, generator);
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
  void rollback(ProjectModel project) {
    _addGenerator(project, generator, index);
  }
}
