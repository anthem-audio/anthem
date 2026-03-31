/*
  Copyright (C) 2025 - 2026 Joshua Wade

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
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processors/processor.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'sequence_note_provider.g.dart';

/// A special-case node that acts as a bridge between the sequencer and the
/// processing graph for the purpose of providing note events to the sequencer.
///
/// See also the C++ implementation in
/// engine/src/modules/processors/sequence_note_provider.h.
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'SequenceNoteProviderProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/sequence_note_provider.h',
)
class SequenceNoteProviderProcessorModel
    extends _SequenceNoteProviderProcessorModel
    with
        Processor,
        _$SequenceNoteProviderProcessorModel,
        _$SequenceNoteProviderProcessorModelAnthemModelMixin {
  SequenceNoteProviderProcessorModel({
    required super.nodeId,
    required super.trackId,
  });

  SequenceNoteProviderProcessorModel.create({
    required ProjectEntityIdAllocator idAllocator,
    required super.trackId,
  }) : super(nodeId: idAllocator.allocateId());

  SequenceNoteProviderProcessorModel.uninitialized()
    : super(nodeId: -1, trackId: -1);

  factory SequenceNoteProviderProcessorModel.fromJson(
    Map<String, dynamic> json,
  ) => _$SequenceNoteProviderProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this,
      eventOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: eventOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.event),
        ),
      ]),
    );
  }

  static int get eventOutputPortId =>
      _SequenceNoteProviderProcessorModel.eventOutputPortId;

  /// Reserved sequence event-list key used for events that are not associated
  /// with a specific track in the source sequence.
  ///
  /// Note that this constant is duplicated in the engine. Search for "NO_TRACK"
  /// in the repo to find it.
  static const String noTrackEventListKey = 'NO_TRACK';
}

abstract class _SequenceNoteProviderProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const int eventOutputPortId = 0;

  Id nodeId;

  /// The ID of the track that this node is providing note events for.
  Id trackId;

  _SequenceNoteProviderProcessorModel({
    required this.nodeId,
    required this.trackId,
  });
}
