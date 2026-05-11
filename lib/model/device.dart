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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/port_ref.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'device.g.dart';

@AnthemEnum()
enum DeviceType { toneGenerator, utility, vst3Plugin }

@AnthemModel.syncedModel()
class DeviceModel extends _DeviceModel
    with _$DeviceModel, _$DeviceModelAnthemModelMixin {
  DeviceModel({
    required ProjectEntityIdAllocator idAllocator,
    required super.name,
    required super.type,
    AnthemObservableList<Id>? nodeIds,
    AnthemObservableList<Id>? connectionIds,
    super.defaultAudioInputPort,
    super.defaultAudioOutputPort,
    super.defaultEventInputPort,
    super.defaultEventOutputPort,
  }) : super(
         id: idAllocator.allocateId(),
         nodeIds: nodeIds ?? AnthemObservableList(),
         connectionIds: connectionIds ?? AnthemObservableList(),
       );

  DeviceModel.uninitialized()
    : super(
        id: -1,
        name: '',
        type: DeviceType.toneGenerator,
        nodeIds: AnthemObservableList(),
        connectionIds: AnthemObservableList(),
      );

  factory DeviceModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceModelAnthemModelMixin.fromJson(json);

  List<NodeModel> getOwnedNodes() {
    return nodeIds
        .map((nodeId) => project.processingGraph.nodes[nodeId])
        .nonNulls
        .toList(growable: false);
  }
}

abstract class _DeviceModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  Id id;

  @anthemObservable
  String name;

  @anthemObservable
  DeviceType type;

  @anthemObservable
  @hideFromCpp
  bool isCollapsed = false;

  @anthemObservable
  AnthemObservableList<Id> nodeIds;

  /// Internal graph connections owned by this device.
  ///
  /// Connections generated for rack routing live on the owning track.
  @anthemObservable
  AnthemObservableList<Id> connectionIds;

  @anthemObservable
  ProcessingGraphPortRefModel? defaultAudioInputPort;

  @anthemObservable
  ProcessingGraphPortRefModel? defaultAudioOutputPort;

  @anthemObservable
  ProcessingGraphPortRefModel? defaultEventInputPort;

  @anthemObservable
  ProcessingGraphPortRefModel? defaultEventOutputPort;

  _DeviceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.nodeIds,
    required this.connectionIds,
    this.defaultAudioInputPort,
    this.defaultAudioOutputPort,
    this.defaultEventInputPort,
    this.defaultEventOutputPort,
  });
}
