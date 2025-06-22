/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

part 'generator.g.dart';

// Note: I'm not sure about how we're differentiating generator types here. This
// is well-defined in the audio engine, but we need to know what kind of data to
// feed the node (automation, audio, events) and what port to send it, and
// that's a sequencer problem. Once the sequencer exists, we should revisit
// this.

@AnthemEnum()
enum GeneratorType { instrument, automation }

@AnthemModel.syncedModel()
class GeneratorModel extends _GeneratorModel
    with _$GeneratorModel, _$GeneratorModelAnthemModelMixin {
  GeneratorModel.uninitialized()
    : super(
        color: Colors.black,
        id: '',
        name: '',
        generatorType: GeneratorType.instrument,
        generatorNodeId: null,
        gainNodeId: null,
        // midiGenNodeId: null,
        sequenceNoteProviderNodeId: null,
      );

  GeneratorModel({
    required super.id,
    required super.name,
    required super.generatorType,
    required super.color,
    required super.generatorNodeId,
    required super.gainNodeId,
    // required super.midiGenNodeId,
    required super.sequenceNoteProviderNodeId,
  });

  factory GeneratorModel.fromJson(Map<String, dynamic> json) =>
      _$GeneratorModelAnthemModelMixin.fromJson(json);
}

abstract class _GeneratorModel with Store, AnthemModelBase {
  String id;

  @anthemObservable
  String name;

  @anthemObservable
  GeneratorType generatorType;

  @anthemObservable
  Color color;

  /// The ID of the node that this generator is using.
  @anthemObservable
  String? generatorNodeId;

  /// The ID of the gain node that this generator outputs to.
  ///
  /// The singal flow is as follows:
  ///     plugin -> gainNode -> (some target)
  ///
  /// The gain node is used for the volume knobs on the generator row.
  @anthemObservable
  String? gainNodeId;

  // @anthemObservable
  // String? midiGenNodeId;

  @anthemObservable
  String? sequenceNoteProviderNodeId;

  _GeneratorModel({
    required this.id,
    required this.name,
    required this.generatorType,
    required this.color,
    required this.generatorNodeId,
    required this.gainNodeId,
    // required this.midiGenNodeId,
    required this.sequenceNoteProviderNodeId,
  }) : super();
}
