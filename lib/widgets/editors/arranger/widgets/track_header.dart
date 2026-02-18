/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/slider.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/context_menu_api.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class TrackHeader extends StatelessObserverWidget {
  final Id trackId;

  const TrackHeader({super.key, required this.trackId});

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final projectServices = ServiceRegistry.forProject(project.id);
    final projectController = projectServices.projectController;
    final track = project.tracks[trackId]!;

    final projectServiceRegistry = ServiceRegistry.forProject(project.id);
    final controller = projectServiceRegistry.arrangerController;
    final viewModel = projectServiceRegistry.arrangerViewModel;

    final trackAnthemColor = track.color;
    final colorShifter = trackAnthemColor.colorShifter;
    final color = colorShifter.clipBase.toColor();

    final trackBackgroundColor = viewModel.selectedTracks.contains(track.id)
        ? AnthemTheme.panel.borderLight
        : AnthemTheme.panel.main;

    final trackHeight = viewModel.trackPositionCalculator.getTrackHeight(
      viewModel.trackPositionCalculator.trackIdToIndex(trackId),
    );

    void onClick() {
      if (HardwareKeyboard.instance.isShiftPressed) {
        controller.shiftClickToTrack(track.id);
        return;
      }

      if (HardwareKeyboard.instance.isControlPressed) {
        controller.toggleTrackSelection(track.id);
        return;
      }

      controller.selectTrack(track.id);
    }

    void onSecondaryClick(TapUpDetails e) {
      if (!controller.isTrackSelected(track.id)) {
        controller.selectTrack(track.id);
      }

      openContextMenu(
        e.globalPosition,
        MenuDef(
          children: [
            AnthemMenuItem(
              text: 'Insert track',
              hint: track.type == .group
                  ? 'Add a track at the end of this group'
                  : 'Insert a track below this track',
              onSelected: () {
                projectController.insertTrackAt(track.id);
              },
            ),
            if (viewModel.selectedTracks.length == 1)
              AnthemMenuItem(
                text: 'Delete',
                hint: 'Delete this track',
                onSelected: () {
                  projectController.removeTrack(track.id);
                },
              ),
            if (viewModel.selectedTracks.length > 1)
              AnthemMenuItem(
                text: 'Delete selected',
                hint: 'Delete the selected tracks',
                onSelected: () {
                  projectController.removeTracks(
                    viewModel.selectedTracks.nonObservableInner,
                  );
                },
              ),
            AnthemMenuItem(
              text: 'Group',
              hint:
                  'Add the selected track${viewModel.selectedTracks.length == 1 ? 's' : ''} to a new track group',
              disabled: !projectController.canGroupTracks(
                viewModel.selectedTracks.nonObservableInner,
              ),
              onSelected: () {
                projectController.groupTracks(
                  viewModel.selectedTracks.nonObservableInner,
                );
              },
            ),
          ],
        ),
      );
    }

    Widget colorIndicator(Color colorToUse, [bool isGroup = false]) {
      return Container(
        width: 9,
        decoration: BoxDecoration(
          color: colorToUse,
          border: Border(
            right: BorderSide(color: AnthemTheme.panel.border, width: 1),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onClick,
        onSecondaryTapUp: onSecondaryClick,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              colorIndicator(color),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: trackHeight - 1,
                      color: trackBackgroundColor,
                      child: _TrackContent(track: track),
                    ),
                    SizedBox(height: 1),
                    ...track.childTracks.map(
                      (trackId) => TrackHeader(trackId: trackId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackContent extends StatelessWidget {
  final TrackModel track;

  const _TrackContent({required this.track});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        const heightThreshold1 = 52;
        const heightThreshold2 = 78;

        return Observer(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Center(
                child: Row(
                  crossAxisAlignment: height >= heightThreshold1
                      ? .start
                      : .center,
                  spacing: 4,
                  children: [
                    Expanded(
                      child: Text(
                        track.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: height >= heightThreshold1 ? 2 : 1,
                        style: TextStyle(
                          color: AnthemTheme.text.main,
                          fontSize: 11,
                          fontWeight: .w500,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .stretch,
                        spacing: 4,
                        children: [
                          _TrackControlButtons(),
                          if (height >= heightThreshold1)
                            Slider(value: 0.75, height: 20, borderRadius: 4),
                          if (height >= heightThreshold2)
                            Slider(
                              value: 0,
                              height: 20,
                              borderRadius: 4,
                              type: .pan,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 9,
                      // This is a bit ugly but avoids an IntrinsicHeight, which the
                      // docs say is slow, and I don't really want to find out why
                      height: height >= heightThreshold2
                          ? 68
                          : height >= heightThreshold1
                          ? 44
                          : 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: AnthemTheme.panel.border),
                        borderRadius: .circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TrackControlButtons extends StatelessWidget {
  const _TrackControlButtons();

  @override
  Widget build(BuildContext context) {
    Widget separator() => Container(width: 1, color: AnthemTheme.panel.border);

    return Column(
      mainAxisSize: .min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AnthemTheme.panel.border),
            borderRadius: BorderRadius.circular(4),
          ),
          height: 20,
          child: Row(
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: Button(
                  hideBorder: true,
                  borderRadius: .horizontal(left: .circular(3)),
                  contentBuilder: (context, color) {
                    return Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: .circular(5),
                        ),
                      ),
                    );
                  },
                ),
              ),
              separator(),
              Expanded(
                child: Button(
                  hideBorder: true,
                  borderRadius: .zero,
                  contentPadding: .all(4),
                  icon: Icons.solo,
                ),
              ),
              separator(),
              Expanded(
                child: Button(
                  hideBorder: true,
                  borderRadius: .horizontal(right: .circular(3)),
                  contentPadding: .all(4),
                  icon: Icons.mute,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
