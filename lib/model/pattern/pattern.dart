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

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/main.dart';
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/widgets/basic/clip/clip_notes_render_cache.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:mobx/mobx.dart';

import '../shared/time_signature.dart';
import 'automation_lane.dart';
import 'note.dart';

part 'pattern.g.dart';
part 'package:anthem/widgets/basic/clip/clip_title_render_cache_mixin.dart';
part 'package:anthem/widgets/basic/clip/clip_notes_render_cache_mixin.dart';

@AnthemModel.syncedModel()
class PatternModel extends _PatternModel
    with
        _$PatternModel,
        _$PatternModelAnthemModelMixin,
        _ClipTitleRenderCacheMixin,
        _ClipNotesRenderCacheMixin {
  PatternModel() : super() {
    _init();
  }

  PatternModel.create({required super.name}) : super.create() {
    _init();

    onModelAttached(() {
      // I had a todo comment to remove this, but I have no idea why, so I'm
      // leaving this comment instead. ¯\_(ツ)_/¯
      for (final generator in project.generators.values.where(
          (generator) => generator.generatorType == GeneratorType.automation)) {
        automationLanes[generator.id] = AutomationLaneModel();
      }
    });
  }

  factory PatternModel.fromJson(Map<String, dynamic> json) {
    final result = _$PatternModelAnthemModelMixin.fromJson(json);
    result._init();
    return result;
  }

  void _init() {
    onModelAttached(() {
      incrementClipUpdateSignal = Action(() {
        clipNotesUpdateSignal.value =
            (clipNotesUpdateSignal.value + 1) % 0xFFFFFFFF;
      });
      updateClipTitleCache();
      updateClipNotesRenderCache();
    });
  }
}

abstract class _PatternModel with Store, AnthemModelBase {
  Id id = getId();

  @anthemObservable
  String name = '';

  @anthemObservable
  AnthemColor color = AnthemColor(hue: 0);

  /// The ID here is channel ID `Map<ChannelID, List<NoteModel>>`
  @anthemObservable
  AnthemObservableMap<Id, AnthemObservableList<NoteModel>> notes =
      AnthemObservableMap();

  /// The ID here is channel ID
  @anthemObservable
  AnthemObservableMap<Id, AutomationLaneModel> automationLanes =
      AnthemObservableMap();

  @anthemObservable
  AnthemObservableList<TimeSignatureChangeModel> timeSignatureChanges =
      AnthemObservableList();

  /// For deserialization. Use `PatternModel.create()` instead.
  _PatternModel();

  _PatternModel.create({
    required this.name,
  }) {
    color = AnthemColor(
      hue: 0,
      saturationMultiplier: 0,
    );
    timeSignatureChanges = AnthemObservableList();
  }

  /// Gets the time position of the end of the last item in this pattern
  /// (note, audio clip, automation point), rounded upward to the nearest
  /// `barMultiple` bars.
  int getWidth({
    int barMultiple = 1,
    int minPaddingInBarMultiples = 1,
  }) {
    final ticksPerBarDouble = project.sequence.ticksPerQuarter /
            (project.sequence.defaultTimeSignature.denominator / 4) *
            project.sequence.defaultTimeSignature.numerator;
    final ticksPerBar = ticksPerBarDouble.round();

    // It should not be possible for ticksPerBar to be fractional.
    // ticksPerQuarter must be divisible by every possible value of
    // (denominator / 4). Denominator can be [1, 2, 4, 8, 16, 32]. Therefore,
    // ticksPerQuarter must be divisible by [0.25, 0.5, 1, 2, 4, 8].
    assert(ticksPerBarDouble == ticksPerBar);

    final lastNoteContent = notes.values.expand((e) => e).fold<int>(
        ticksPerBar * barMultiple * minPaddingInBarMultiples,
        (previousValue, note) =>
            max(previousValue, (note.offset + note.length)));

    final lastAutomationContent = automationLanes.values.fold<int>(
      ticksPerBar * barMultiple * minPaddingInBarMultiples,
      (previousValue, automationLane) =>
          max(previousValue, automationLane.points.lastOrNull?.offset ?? 0),
    );

    final lastContent = max(lastNoteContent, lastAutomationContent);

    return (max(lastContent, 1) / (ticksPerBar * barMultiple)).ceil() *
        ticksPerBar *
        barMultiple;
  }

  @computed
  int get lastContent {
    return getWidth(barMultiple: 4, minPaddingInBarMultiples: 4);
  }

  @computed
  bool get hasTimeMarkers {
    return timeSignatureChanges.isNotEmpty;
  }
}
