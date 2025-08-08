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
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/model.dart';

import 'command.dart';

void _addGenerator(
  ProjectModel project,
  GeneratorModel generator, {
  int? index,
  required NodeModel generatorNode,
  required NodeModel gainNode,
  // required NodeModel midiGenNode,
  required NodeModel sequenceNoteProviderNode,
  required NodeModel liveEventProviderNode,

  Map<Id, AnthemObservableList<NoteModel>>? notes,
  Map<Id, AutomationLaneModel>? automationLanes,
}) {
  if (index != null) {
    project.generatorOrder.insert(index, generator.id);
  } else {
    project.generatorOrder.add(generator.id);
  }
  project.generators[generator.id] = generator;

  // If the node has no processor, treat this as a dummy generator. We use this
  // for testing so we need this case.
  if (generatorNode.processor == null) {
    return;
  }

  project.processingGraph.addNode(generatorNode);
  project.processingGraph.addNode(gainNode);
  // project.processingGraph.addNode(midiGenNode);
  project.processingGraph.addNode(sequenceNoteProviderNode);
  project.processingGraph.addNode(liveEventProviderNode);

  // project.processingGraph.addConnection(
  //   NodeConnectionModel(
  //     id: getId(),
  //     sourceNodeId: midiGenNode.id,
  //     sourcePortId: midiGenNode.eventOutputPorts[0].id,
  //     destinationNodeId: generatorNode.id,
  //     destinationPortId: generatorNode.eventInputPorts[0].id,
  //   ),
  // );
  project.processingGraph.addConnection(
    NodeConnectionModel(
      id: getId(),
      sourceNodeId: sequenceNoteProviderNode.id,
      sourcePortId: sequenceNoteProviderNode.eventOutputPorts[0].id,
      destinationNodeId: generatorNode.id,
      destinationPortId: generatorNode.eventInputPorts[0].id,
    ),
  );
  project.processingGraph.addConnection(
    NodeConnectionModel(
      id: getId(),
      sourceNodeId: generatorNode.id,
      sourcePortId: generatorNode.audioOutputPorts[0].id,
      destinationNodeId: gainNode.id,
      destinationPortId: gainNode.audioInputPorts[0].id,
    ),
  );
  project.processingGraph.addConnection(
    NodeConnectionModel(
      id: getId(),
      sourceNodeId: gainNode.id,
      sourcePortId: gainNode.audioOutputPorts[0].id,
      destinationNodeId: project.processingGraph.masterOutputNodeId,
      destinationPortId: project.processingGraph
          .getMasterOutputNode()
          .audioInputPorts[0]
          .id,
    ),
  );
  project.processingGraph.addConnection(
    NodeConnectionModel(
      id: getId(),
      sourceNodeId: liveEventProviderNode.id,
      sourcePortId: liveEventProviderNode.eventOutputPorts[0].id,
      destinationNodeId: generatorNode.id,
      destinationPortId: generatorNode.eventInputPorts[0].id,
    ),
  );

  // Add back sequence data for this generator to all patterns
  for (final pattern in project.sequence.patterns.values) {
    if (notes != null && notes.containsKey(pattern.id)) {
      pattern.notes[generator.id] = notes[pattern.id]!;
    }

    if (automationLanes != null && automationLanes.containsKey(pattern.id)) {
      pattern.automationLanes[generator.id] = automationLanes[pattern.id]!;
    }
  }

  project.engine.processingGraphApi.compile();
}

void _removeGenerator(ProjectModel project, Id generatorID) {
  GeneratorModel? generator;

  project.generatorOrder.removeWhere((element) => element == generatorID);
  if (project.generators.containsKey(generatorID)) {
    generator = project.generators.remove(generatorID);
  }

  if (generator == null || generator.generatorNodeId == null) {
    return;
  }

  project.processingGraph.removeNode(generator.generatorNodeId!);
  project.processingGraph.removeNode(generator.gainNodeId!);
  // project.processingGraph.removeNode(generator.midiGenNodeId!);
  project.processingGraph.removeNode(generator.sequenceNoteProviderNodeId!);
  project.processingGraph.removeNode(generator.liveEventProviderNodeId!);

  // Remove sequence data for this generator from all patterns
  for (final pattern in project.sequence.patterns.values) {
    if (pattern.notes.containsKey(generatorID)) {
      pattern.notes.remove(generatorID);
    }

    if (pattern.automationLanes.containsKey(generatorID)) {
      pattern.automationLanes.remove(generatorID);
    }
  }

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
    final gainNode = GainProcessorModel.createNode();
    // final midiGenNode = SimpleMidiGeneratorProcessorModel.createNode();
    final sequencerNoteProviderNode =
        SequenceNoteProviderProcessorModel.createNode(generatorId);
    final liveEventProviderNode = LiveEventProviderProcessorModel.createNode(
      generatorId,
    );

    final generator = GeneratorModel(
      id: generatorId,
      name: name,
      generatorType: generatorType,
      color: color,
      generatorNodeId: node.id,
      gainNodeId: gainNode.id,
      // midiGenNodeId: midiGenNode.id,
      sequenceNoteProviderNodeId: sequencerNoteProviderNode.id,
      liveEventProviderNodeId: liveEventProviderNode.id,
    );

    _addGenerator(
      project,
      generator,
      generatorNode: node,
      gainNode: gainNode,
      liveEventProviderNode: liveEventProviderNode,

      // midiGenNode: midiGenNode,
      sequenceNoteProviderNode: sequencerNoteProviderNode,
    );
  }

  @override
  void rollback(ProjectModel project) {
    _removeGenerator(project, generatorId);
  }
}

class RemoveGeneratorCommand extends Command {
  GeneratorModel generator;
  NodeModel generatorNode;
  NodeModel gainNode;
  // NodeModel midiGenNode;
  NodeModel sequenceNoteProviderNode;
  NodeModel liveEventProviderNode;
  late int index;

  /// Map of pattern ID to notes for this generator.
  Map<Id, AnthemObservableList<NoteModel>>? notes;

  /// Map of pattern ID to notes for this generator.
  Map<Id, AutomationLaneModel>? automationLanes;

  RemoveGeneratorCommand({
    required ProjectModel project,
    required this.generator,
  }) : generatorNode =
           project.processingGraph.nodes[generator.generatorNodeId]!,
       gainNode = project.processingGraph.nodes[generator.gainNodeId]!,
       //  midiGenNode = project.processingGraph.nodes[generator.midiGenNodeId]!
       sequenceNoteProviderNode =
           project.processingGraph.nodes[generator // what is this formatting
               .sequenceNoteProviderNodeId]!,
       liveEventProviderNode =
           project.processingGraph.nodes[generator.liveEventProviderNodeId]! {
    index = project.generatorOrder.indexOf(generator.id);

    notes = {};
    for (final pattern in project.sequence.patterns.values) {
      if (pattern.notes.containsKey(generator.id)) {
        notes![pattern.id] = pattern.notes[generator.id]!;
      }
    }

    automationLanes = {};
    for (final pattern in project.sequence.patterns.values) {
      if (pattern.automationLanes.containsKey(generator.id)) {
        automationLanes![pattern.id] = pattern.automationLanes[generator.id]!;
      }
    }
  }

  @override
  void execute(ProjectModel project) {
    _removeGenerator(project, generator.id);
  }

  @override
  void rollback(ProjectModel project) {
    _addGenerator(
      project,
      generator,
      index: index,
      generatorNode: generatorNode,
      gainNode: gainNode,
      // midiGenNode: midiGenNode,
      sequenceNoteProviderNode: sequenceNoteProviderNode,
      liveEventProviderNode: liveEventProviderNode,

      notes: notes,
      automationLanes: automationLanes,
    );
  }
}
