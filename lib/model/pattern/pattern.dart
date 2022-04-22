/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:json_annotation/json_annotation.dart';

import '../shared/time_signature.dart';
import 'note.dart';

part 'pattern.g.dart';

double _hueGen = 0;

@JsonSerializable()
class PatternModel {
  ID id;

  String name;
  AnthemColor color;

  Map<ID, List<NoteModel>> notes;
  List<TimeSignatureChangeModel> timeSignatureChanges;
  TimeSignatureModel defaultTimeSignature; // TODO: Just pull from project??

  PatternModel(this.name)
      : id = getID(),
        notes = HashMap(),
        timeSignatureChanges = [],
        defaultTimeSignature = TimeSignatureModel(4, 4),
        color = AnthemColor(
          hue: (() {
            final result = _hueGen;
            _hueGen = (_hueGen + 30) % 360;
            return result;
          })(),
          brightnessModifier: 0,
        );

  factory PatternModel.fromJson(Map<String, dynamic> json) =>
      _$PatternModelFromJson(json);

  Map<String, dynamic> toJson() => _$PatternModelToJson(this);

  @override
  String toString() => json.encode(toJson());

  /// Gets the time position of the end of the last item in this pattern
  /// (note, audio clip, automation point), rounded upward to the nearest
  /// `barMultiple` bars.
  int getWidth({
    required int ticksPerQuarter,
    int barMultiple = 1,
    int minPaddingInBarMultiples = 1,
  }) {
    // TODO: Time signature changes

    final ticksPerBar = ticksPerQuarter ~/
        (defaultTimeSignature.denominator ~/ 4) *
        defaultTimeSignature.numerator;
    final lastContent = notes.values.expand((e) => e).fold<int>(
        ticksPerBar * barMultiple * minPaddingInBarMultiples,
        (previousValue, note) =>
            max(previousValue, (note.offset + note.length)));

    return (max(lastContent, 1) / (ticksPerBar * barMultiple)).ceil() *
        ticksPerBar *
        barMultiple;
  }
}
