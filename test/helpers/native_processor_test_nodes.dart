/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/model/model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:anthem/model/processing_graph/processors/db_meter.dart';

/// All native processor types, with node IDs allocated by a real project.
List<NodeModel> createNativeProcessorTestNodes(ProjectModel project) => [
  BalanceProcessorModel(nodeId: project.allocateId()).createNode(),
  ControlValueVisualizationProcessorModel(
    nodeId: project.allocateId(),
    visualizationId: 'native-port-contract',
  ).createNode(),
  DbMeterProcessorModel(
    nodeId: project.allocateId(),
    publishEverySamples: 1024,
    visualizationIds: AnthemObservableList(),
  ).createNode(),
  GainProcessorModel(nodeId: project.allocateId()).createNode(),
  LiveEventProviderProcessorModel(nodeId: project.allocateId()).createNode(),
  MasterOutputProcessorModel(nodeId: project.allocateId()).createNode(),
  SequenceAutomationProviderProcessorModel(
    nodeId: project.allocateId(),
    trackId: project.trackOrder.single,
    emptyValue: 0.0,
  ).createNode(),
  SequenceNoteProviderProcessorModel(
    nodeId: project.allocateId(),
    trackId: project.trackOrder.single,
  ).createNode(),
  SimpleMidiGeneratorProcessorModel(nodeId: project.allocateId()).createNode(),
  SimpleVolumeLfoProcessorModel(nodeId: project.allocateId()).createNode(),
  ToneGeneratorProcessorModel(nodeId: project.allocateId()).createNode(),
  UtilityProcessorModel(nodeId: project.allocateId())
      .createNode(initialGainDb: -10),
];
