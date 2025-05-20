/*
  Copyright (C) 2025 Joshua Wade

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
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'sequence_note_provider.g.dart';

/// A special-case node that acts as a bridge between the sequener and the
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
        _$SequenceNoteProviderProcessorModel,
        _$SequenceNoteProviderProcessorModelAnthemModelMixin {
  SequenceNoteProviderProcessorModel({
    required super.nodeId,
    required super.channelId,
  });

  SequenceNoteProviderProcessorModel.uninitialized()
    : super(nodeId: '', channelId: '');

  factory SequenceNoteProviderProcessorModel.fromJson(
    Map<String, dynamic> json,
  ) => _$SequenceNoteProviderProcessorModelAnthemModelMixin.fromJson(json);

  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  static NodeModel createNode(String channelId) {
    final id = 'sequence-note-provider-${getId()}';

    return NodeModel(
      id: id,
      processor: SequenceNoteProviderProcessorModel(
        nodeId: id,
        channelId: channelId,
      ),
      eventOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: eventOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.event),
        ),
      ]),
    );
  }

  static int get eventOutputPortId =>
      _SequenceNoteProviderProcessorModel.eventOutputPortId;
}

abstract class _SequenceNoteProviderProcessorModel with Store, AnthemModelBase {
  static const int eventOutputPortId = 0;

  String nodeId;

  /// The ID of the channel that this node is providing note events for.
  String channelId;

  _SequenceNoteProviderProcessorModel({
    required this.nodeId,
    required this.channelId,
  });
}
