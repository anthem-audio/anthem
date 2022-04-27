/*
  Copyright (C) 2022 Joshua Wade

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

import 'dart:convert';
import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/hydratable.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:json_annotation/json_annotation.dart';

import 'clip.dart';

part 'arrangement.g.dart';

@JsonSerializable()
class ArrangementModel extends Hydratable {
  ID id;
  String name;
  Map<ID, ClipModel> clips = {};
  TimeSignatureModel defaultTimeSignature = TimeSignatureModel(4, 4);

  @JsonKey(ignore: true)
  ProjectModel? _project;

  ProjectModel get project {
    return _project!;
  }

  ArrangementModel({
    required this.name,
    required this.id,
  }) : super();

  ArrangementModel.create({
    required this.name,
    required this.id,
    required ProjectModel project,
  }) : super() {
    hydrate(project: project);
  }

  factory ArrangementModel.fromJson(Map<String, dynamic> json) =>
      _$ArrangementModelFromJson(json);

  Map<String, dynamic> toJson() => _$ArrangementModelToJson(this);

  @override
  String toString() => json.encode(toJson());

  void hydrate({required ProjectModel project}) {
    _project = project;
    for (final clip in clips.values) {
      clip.hydrate(project: project);
    }
    isHydrated = true;
  }

  /// Gets the time position of the end of the last clip in this arrangement,
  /// rounded upward to the nearest `barMultiple` bars.
  int getWidth({
    int barMultiple = 4,
    int minPaddingInBarMultiples = 4,
  }) {
    // TODO: Time signature changes

    final ticksPerBar = project.song.ticksPerQuarter ~/
        (defaultTimeSignature.denominator ~/ 4) *
        defaultTimeSignature.numerator;
    final lastContent = clips.values.fold<int>(
      ticksPerBar * barMultiple * minPaddingInBarMultiples,
      (previousValue, clip) => max(
        previousValue,
        clip.offset + clip.getWidth(),
      ),
    );

    return (max(lastContent, 1) / (ticksPerBar * barMultiple)).ceil() *
        ticksPerBar *
        barMultiple;
  }
}
