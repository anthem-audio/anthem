/*
  Copyright (C) 2021 - 2024 Joshua Wade

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
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/shared/hydratable.dart';
import 'package:anthem/widgets/basic/clip/clip_notes_render_cache.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem_codegen/annotations.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:mobx/mobx.dart';

import '../shared/time_signature.dart';
import 'automation_lane.dart';
import 'note.dart';

part 'pattern.g.dart';
part 'package:anthem/widgets/basic/clip/clip_title_render_cache_mixin.dart';
part 'package:anthem/widgets/basic/clip/clip_notes_render_cache_mixin.dart';

@AnthemModel.all()
class PatternModel extends _PatternModel
    with
        _$PatternModel,
        _$PatternModelAnthemModelMixin,
        _ClipTitleRenderCacheMixin,
        _ClipNotesRenderCacheMixin {
  PatternModel() : super() {
    _init();
  }

  PatternModel.create({required super.name, required ProjectModel project})
      : super.create(project: project) {
    _init();
    // TODO: remove
    for (final generator in project.generators.values.where(
        (generator) => generator.generatorType == GeneratorType.automation)) {
      automationLanes[generator.id] = AutomationLaneModel();
    }
    super.hydrate(project: project);
  }

  factory PatternModel.fromJson(Map<String, dynamic> json) {
    final result = _$PatternModelAnthemModelMixin.fromJson(json);
    result._init();
    return result;
  }

  void _init() {
    if (isHydrated) throw Exception('Should always init before hydrate');

    super._onHydrateAction = () {
      incrementClipUpdateSignal = Action(() {
        clipNotesUpdateSignal.value =
            (clipNotesUpdateSignal.value + 1) % 0xFFFFFFFF;
      });
      updateClipTitleCache();
      updateClipNotesRenderCache();
    };
  }
}

abstract class _PatternModel extends Hydratable with Store {
  @hide
  void Function()? _onHydrateAction;

  ID id = getID();

  @anthemObservable
  String name = '';

  @anthemObservable
  AnthemColor color = AnthemColor(hue: 0);

  /// The ID here is channel ID `Map<ChannelID, List<NoteModel>>`
  @anthemObservable
  ObservableMap<ID, ObservableList<NoteModel>> notes = ObservableMap();

  /// The ID here is channel ID
  @anthemObservable
  ObservableMap<ID, AutomationLaneModel> automationLanes = ObservableMap();

  @anthemObservable
  ObservableList<TimeSignatureChangeModel> timeSignatureChanges =
      ObservableList();

  @hide
  ProjectModel? _project;

  ProjectModel get project {
    return _project!;
  }

  /// For deserialization. Use `PatternModel.create()` instead.
  _PatternModel();

  _PatternModel.create({
    required this.name,
    required ProjectModel project,
  }) {
    color = AnthemColor(
      hue: 0,
      saturationMultiplier: 0,
    );
    timeSignatureChanges = ObservableList();
  }

  void hydrate({required ProjectModel project}) {
    _project = project;

    _onHydrateAction?.call();
    _onHydrateAction = null;

    isHydrated = true;
  }

  /// Gets the time position of the end of the last item in this pattern
  /// (note, audio clip, automation point), rounded upward to the nearest
  /// `barMultiple` bars.
  int getWidth({
    int barMultiple = 1,
    int minPaddingInBarMultiples = 1,
  }) {
    final ticksPerBar = project.song.ticksPerQuarter ~/
        (_project!.song.defaultTimeSignature.denominator ~/ 4) *
        _project!.song.defaultTimeSignature.numerator;

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
