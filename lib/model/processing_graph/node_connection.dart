/*
  Copyright (C) 2024 Joshua Wade

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

import 'package:anthem/model/shared/hydratable.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'node_connection.g.dart';

@AnthemModel.all()
class NodeConnectionModel extends _NodeConnectionModel
    with _$NodeConnectionModel, _$NodeConnectionModelAnthemModelMixin {
  NodeConnectionModel({
    required super.id,
    required super.sourcePortId,
    required super.targetPortId,
  });

  NodeConnectionModel.uninitialized()
      : super(id: '', sourcePortId: '', targetPortId: '');

  factory NodeConnectionModel.fromJson(Map<String, dynamic> json) =>
      _$NodeConnectionModelAnthemModelMixin.fromJson(json);
}

abstract class _NodeConnectionModel extends Hydratable
    with Store, AnthemModelBase {
  String id;

  String sourcePortId;
  String targetPortId;

  _NodeConnectionModel(
      {required this.id,
      required this.sourcePortId,
      required this.targetPortId}) {
    isHydrated = true;
    (this as _$NodeConnectionModelAnthemModelMixin).init();
  }
}
