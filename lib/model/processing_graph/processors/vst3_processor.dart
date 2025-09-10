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
import 'package:anthem/model/model.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'vst3_processor.g.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'VST3Processor',
  cppBehaviorClassIncludePath: 'modules/processors/vst3_processor.h',
  skipOnWasm: true,
)
class VST3ProcessorModel extends _VST3ProcessorModel
    with _$VST3ProcessorModel, _$VST3ProcessorModelAnthemModelMixin {
  VST3ProcessorModel({required super.nodeId, required super.vst3Path});

  VST3ProcessorModel.uninitialized() : super(nodeId: '', vst3Path: '');

  factory VST3ProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$VST3ProcessorModelAnthemModelMixin.fromJson(json);

  /// The node that this processor represents.
  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  /// Creates a node for this processor.
  static NodeModel createNode(String vst3Path) {
    final id = 'vst3-processor-${getId()}';

    return NodeModel(
      isThirdPartyPlugin: true,
      id: id,
      processor: VST3ProcessorModel(nodeId: id, vst3Path: vst3Path),
      eventInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: eventInputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.event),
        ),
      ]),
      audioOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: audioOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
        ),
      ]),
    );
  }

  static int get eventInputPortId => _VST3ProcessorModel.eventInputPortId;
  static int get audioOutputPortId => _VST3ProcessorModel.audioOutputPortId;
}

abstract class _VST3ProcessorModel with AnthemModelBase, Store {
  static const int audioOutputPortId = 0;

  static const int eventInputPortId = 1;

  @anthemObservable
  String nodeId;

  @anthemObservable
  String vst3Path;

  _VST3ProcessorModel({required this.nodeId, required this.vst3Path});
}
