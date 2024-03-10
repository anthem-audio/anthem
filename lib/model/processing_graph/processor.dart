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

import 'package:anthem/engine_api/engine.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'processor.g.dart';

@JsonSerializable()
class ProcessorModel extends _ProcessorModel with _$ProcessorModel {
  ProcessorModel({
    required String? processorKey,
  }) : super(
          processorKey: processorKey,
        );

  factory ProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$ProcessorModelFromJson(json);
}

abstract class _ProcessorModel with Store {
  int? idInEngine;

  @observable
  String? processorKey;

  _ProcessorModel({required this.processorKey});

  Map<String, dynamic> toJson() =>
      _$ProcessorModelToJson(this as ProcessorModel);

  Future<void> createInEngine(Engine engine) async {
    if (processorKey == null) return;

    idInEngine = await engine.projectApi.addProcessor(processorKey!);
  }
}
