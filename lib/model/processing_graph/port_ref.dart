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
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'port_ref.g.dart';

@AnthemModel.syncedModel()
class ProcessingGraphPortRefModel extends _ProcessingGraphPortRefModel
    with
        _$ProcessingGraphPortRefModel,
        _$ProcessingGraphPortRefModelAnthemModelMixin {
  ProcessingGraphPortRefModel({required super.nodeId, required super.portId});

  ProcessingGraphPortRefModel.uninitialized() : super(nodeId: -1, portId: -1);

  factory ProcessingGraphPortRefModel.fromJson(Map<String, dynamic> json) =>
      _$ProcessingGraphPortRefModelAnthemModelMixin.fromJson(json);
}

abstract class _ProcessingGraphPortRefModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  Id nodeId;
  int portId;

  _ProcessingGraphPortRefModel({required this.nodeId, required this.portId});
}
