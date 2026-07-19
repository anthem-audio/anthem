/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_headers.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class ArrangerTrackHeadersWidgetTestScreen extends StatefulWidget {
  const ArrangerTrackHeadersWidgetTestScreen({super.key});

  @override
  State<ArrangerTrackHeadersWidgetTestScreen> createState() =>
      _ArrangerTrackHeadersWidgetTestScreenState();
}

class _ArrangerTrackHeadersWidgetTestScreenState
    extends State<ArrangerTrackHeadersWidgetTestScreen> {
  late final ProjectModel project;
  late final ArrangerViewModel viewModel;
  late final ArrangerController controller;

  @override
  void initState() {
    super.initState();

    project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);
    final services = ServiceRegistry.forProject(project.id);
    viewModel = services.arrangerViewModel;
    controller = services.arrangerController;

    final kick = project.tracks[project.trackOrder.first]!
      ..name = 'Kick'
      ..color = AnthemColor(hue: 18, palette: .normal);
    final drums = _createTrack(name: 'Drums', hue: 34, type: TrackType.group);
    kick.parentTrackId = drums.id;
    drums.childTracks.add(kick.id);

    final snare = _createTrack(name: 'Snare', hue: 52)
      ..parentTrackId = drums.id;
    drums.childTracks.add(snare.id);

    final bass = _createTrack(name: 'Bass', hue: 196);

    project.trackOrder
      ..clear()
      ..addAll([drums.id, bass.id]);

    viewModel
      ..registerTrack(drums.id)
      ..registerTrack(snare.id)
      ..registerTrack(bass.id)
      ..setRowHeightModifier(kick.id, 1.35)
      ..setRowHeightModifier(snare.id, 0.82)
      ..setRowHeightModifier(bass.id, 1.1)
      ..selectedTracks.add(kick.id)
      ..automationExpandedByTrackId[bass.id] = true
      ..lastTweakedAutomationTarget = AutomationParameterTarget(
        ownerTrackId: bass.id,
        nodeId: 9001,
        portId: 9002,
        ownerName: 'Bass synth',
        parameterName: 'Filter cutoff',
      );
  }

  TrackModel _createTrack({
    required String name,
    required double hue,
    TrackType type = TrackType.normal,
  }) {
    final track = TrackModel(
      idAllocator: project.idAllocator,
      name: name,
      color: AnthemColor(hue: hue, palette: .normal),
      type: type,
    );
    project.tracks[track.id] = track;
    return track;
  }

  @override
  void dispose() {
    ServiceRegistry.removeProject(project.id);
    project.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ProjectModel>.value(value: project),
        Provider<ArrangerViewModel>.value(value: viewModel),
        Provider<ArrangerController>.value(value: controller),
      ],
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: TrackLayout.defaultHeaderWidth,
          height: 390,
          decoration: BoxDecoration(
            color: AnthemTheme.panel.background,
            border: Border.all(color: AnthemTheme.panel.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              viewModel.refreshTrackLayout(
                constraints.maxHeight,
                headerWidth: constraints.maxWidth,
              );
              return const TrackHeaders(verticalScrollPosition: 0);
            },
          ),
        ),
      ),
    );
  }
}
