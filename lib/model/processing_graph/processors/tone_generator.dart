/*
  Copyright (C) 2024 - 2026 Joshua Wade

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
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processors/processor.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'native_node_bootstrap.dart';

part 'tone_generator.g.dart';

/// A processor that generates a tone.
///
/// Parameter values are stored normalized. The frequency parameter is
/// interpreted as a linear mapping to [minFrequencyHz, maxFrequencyHz], and
/// amplitude is interpreted directly as a
/// normalized amplitude.
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'ToneGeneratorProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/tone_generator.h',
)
class ToneGeneratorProcessorModel extends _ToneGeneratorProcessorModel
    with
        Processor,
        _$ToneGeneratorProcessorModel,
        _$ToneGeneratorProcessorModelAnthemModelMixin {
  ToneGeneratorProcessorModel({required super.nodeId});

  ToneGeneratorProcessorModel.create({
    required ProjectEntityIdAllocator idAllocator,
  }) : super(nodeId: idAllocator.allocateId());

  ToneGeneratorProcessorModel.uninitialized() : super(nodeId: -1);

  factory ToneGeneratorProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$ToneGeneratorProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() => createNativeNode(
    processor: this,
    audioOutputPortIds: [audioOutputPortId],
    eventInputPortIds: [eventInputPortId],
    parameters: [
      NativeParameterPreset(
        id: frequencyPortId,
        value: frequencyToParameterValue(440.0),
        displayMode: ParameterDisplayMode.percent,
      ),
      NativeParameterPreset(
        id: amplitudePortId,
        value: 0.75,
        displayMode: ParameterDisplayMode.percent,
      ),
    ],
  );

  static const int audioOutputPortId =
      _ToneGeneratorProcessorModel.audioOutputPortId;
  static const int frequencyPortId =
      _ToneGeneratorProcessorModel.frequencyPortId;
  static const int amplitudePortId =
      _ToneGeneratorProcessorModel.amplitudePortId;
  static const int eventInputPortId =
      _ToneGeneratorProcessorModel.eventInputPortId;

  static const double minFrequencyHz = 1.0;
  static const double maxFrequencyHz = 22500.0;

  static double parameterValueToFrequency(double parameterValue) {
    assert(parameterValue >= 0.0 && parameterValue <= 1.0);

    return parameterValue * (maxFrequencyHz - minFrequencyHz) + minFrequencyHz;
  }

  static double frequencyToParameterValue(double frequency) {
    assert(frequency >= minFrequencyHz && frequency <= maxFrequencyHz);

    return (frequency - minFrequencyHz) / (maxFrequencyHz - minFrequencyHz);
  }
}

abstract class _ToneGeneratorProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  // Stable port IDs exported to C++ by model codegen.
  static const int audioOutputPortId = 0;
  static const int frequencyPortId = 1;
  static const int amplitudePortId = 2;
  static const int eventInputPortId = 3;

  Id nodeId;

  _ToneGeneratorProcessorModel({required this.nodeId});
}
