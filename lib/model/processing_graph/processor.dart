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

import 'package:anthem/controller/processor_manager/processor_list.dart';
import 'package:anthem/controller/processor_manager/processor_manager.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'processor.g.dart';

@JsonSerializable()
class ProcessorModel extends _ProcessorModel with _$ProcessorModel {
  ProcessorModel({
    required super.processorKey,
  });

  factory ProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$ProcessorModelFromJson(json);
}

abstract class _ProcessorModel with Store {
  int? idInEngine;

  @observable
  String? processorKey;

  @JsonKey(fromJson: _parameterValuesFromJson, toJson: _parameterValuesToJson)
  ObservableMap<int, double> parameterValues = ObservableMap();

  _ProcessorModel({required this.processorKey});

  Map<String, dynamic> toJson() =>
      _$ProcessorModelToJson(this as ProcessorModel);

  Future<void> createInEngine(Engine engine) async {
    if (processorKey == null) return;

    idInEngine = await engine.processingGraphApi.addProcessor(processorKey!);

    await processorManager.validateProcessor(
      engine: engine,
      processorDefinition:
          processorList.firstWhere((processor) => processor.id == processorKey),
      nodeInstanceId: idInEngine!,
    );
  }
}

ObservableMap<int, double> _parameterValuesFromJson(Map<String, dynamic> json) {
  return ObservableMap.of(
      json.map((key, value) => MapEntry(int.parse(key), value)));
}

Map<String, dynamic> _parameterValuesToJson(ObservableMap<int, double> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}
