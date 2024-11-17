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

// import 'package:anthem/controller/processor_manager/processor_list.dart';
// import 'package:anthem/controller/processor_manager/processor_manager.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'processor.g.dart';

@AnthemModel.syncedModel()
class ProcessorModel extends _ProcessorModel
    with _$ProcessorModel, _$ProcessorModelAnthemModelMixin {
  ProcessorModel({
    required super.processorKey,
  });

  ProcessorModel.uninitialized() : super(processorKey: '');

  factory ProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$ProcessorModelAnthemModelMixin.fromJson(json);

  Future<void> createInEngine(Engine engine) async {
    if (processorKey == null) return;

    idInEngine = await engine.processingGraphApi.addProcessor(processorKey!);

    final processorInfo = await engine.processingGraphApi
        .getProcessorPortInfo(processorId: idInEngine!);

    final newParams = <int, double>{};

    for (final parameter in processorInfo.parameters) {
      newParams[parameter.id] = parameter
          .defaultValue; // TODO - This is incorrect. We should get the current parameter value, but we can't yet.
    }

    parameterValues = AnthemObservableMap.of(newParams);

    // Report changes back to the engine
    parameterValues.observe((change) async {
      if (engine.engineState != EngineState.running || idInEngine == null) {
        return;
      }

      if (change.newValue == null || change.oldValue == null) {
        throw AssertionError(
            'Parameters cannot be added or removed from the map.');
      }

      engine.processingGraphApi.setParameter(
        nodeId: idInEngine!,
        parameterId: change.key!,
        value: change.newValue!,
      );
    });

    // We use a weak ref here so that the callback below won't hold on to this object
    final weakRef = WeakReference(this);
    engine.engineStateStream.first.then((state) {
      if (state != EngineState.running) {
        // Set the id in engine to null. This is so the null check above still
        // works if the engine is stopped and started again.
        weakRef.target?.idInEngine = null;
      }
    });

    // await processorManager.validateProcessor(
    //   engine: engine,
    //   processorDefinition:
    //       processorList.firstWhere((processor) => processor.id == processorKey),
    //   nodeInstanceId: idInEngine!,
    // );
  }
}

abstract class _ProcessorModel with Store, AnthemModelBase {
  int? idInEngine;

  @anthemObservable
  String? processorKey;

  AnthemObservableMap<int, double> parameterValues = AnthemObservableMap();

  _ProcessorModel({required this.processorKey}) : super();
}
