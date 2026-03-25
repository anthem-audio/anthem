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
import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/processing_graph/processors/balance.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_group.dart';
import 'package:anthem/widgets/basic/controls/slider.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/meter.dart';
import 'package:anthem/widgets/basic/menu/context_menu_api.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:anthem/visualization/visualization.dart';
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
    final trackController = projectServices.trackController;
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
                trackController.insertTrackAt(track.id);
              },
            ),
            if (viewModel.selectedTracks.length == 1)
              AnthemMenuItem(
                text: 'Delete',
                hint: 'Delete this track',
                disabled: track.isMasterTrack,
                onSelected: () {
                  trackController.removeTrack(track.id);
                },
              ),
            if (viewModel.selectedTracks.length > 1)
              AnthemMenuItem(
                text: 'Delete selected',
                hint: 'Delete the selected tracks',
                disabled: viewModel.selectedTracks.any(
                  (t) => project.tracks[t]?.isMasterTrack ?? false,
                ),
                onSelected: () {
                  trackController.removeTracks(
                    viewModel.selectedTracks.nonObservableInner,
                  );
                },
              ),
            AnthemMenuItem(
              text: 'Group',
              hint:
                  'Add the selected track${viewModel.selectedTracks.length == 1 ? 's' : ''} to a new track group',
              disabled: !trackController.canGroupTracks(
                viewModel.selectedTracks.nonObservableInner,
              ),
              onSelected: () {
                trackController.groupTracks(
                  viewModel.selectedTracks.nonObservableInner.toList(),
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
                            Slider(
                              value:
                                  track.gainNode
                                      ?.getPortById(
                                        GainProcessorModel.gainPortId,
                                      )
                                      .parameterValue ??
                                  gainParameterZeroDbNormalized,
                              min: 0,
                              max: 1,
                              height: 20,
                              borderRadius: 4,
                              stickyPoints: [gainParameterZeroDbNormalized],
                              hint: (v) =>
                                  'Track gain: ${gainParameterValueToString(v)}',
                              onValueChanged: (value) {
                                final node = track.gainNode;
                                if (node == null) return;

                                node
                                        .getPortById(
                                          GainProcessorModel.gainPortId,
                                        )
                                        .parameterValue =
                                    value;
                              },
                            ),
                          if (height >= heightThreshold2)
                            Slider(
                              value:
                                  track.balanceNode
                                      ?.getPortById(
                                        BalanceProcessorModel.balancePortId,
                                      )
                                      .parameterValue ??
                                  0,
                              min: -1,
                              max: 1,
                              height: 20,
                              borderRadius: 4,
                              type: .pan,
                              stickyPoints: [0],
                              hint: (v) => v == 0
                                  ? 'Track balance: Center'
                                  : 'Track balance: ${(v * 100).abs().toStringAsFixed(0)}%${v < 0 ? ' L' : ' R'}',
                              onValueChanged: (value) {
                                final node = track.balanceNode;
                                if (node == null) return;

                                node
                                        .getPortById(
                                          BalanceProcessorModel.balancePortId,
                                        )
                                        .parameterValue =
                                    value;
                              },
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
                        color: AnthemTheme.control.background,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: _TrackDbMeter(track: track),
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

class _TrackDbMeter extends StatelessWidget {
  final TrackModel track;

  const _TrackDbMeter({required this.track});

  @override
  Widget build(BuildContext context) {
    return MultiVisualizationBuilder.double(
      configs: track.dbMeterVisualizationIds
          .map(
            (id) => VisualizationSubscriptionConfig.max(
              id,
              bufferMode: VisualizationBufferMode.adaptive,
            ),
          )
          .toList(growable: false),
      builder: (context, values, engineTimes) {
        final hasStereoValues = values.length >= 2;
        final hasFullTimestampSet =
            engineTimes.length >= 2 &&
            engineTimes[0] != null &&
            engineTimes[1] != null;

        if (!hasStereoValues || !hasFullTimestampSet) {
          return const Meter(
            db: (left: double.negativeInfinity, right: double.negativeInfinity),
            timestamp: Duration.zero,
          );
        }

        final leftTime = engineTimes[0]!;
        final rightTime = engineTimes[1]!;

        return Meter(
          noBackground: true,
          db: (left: values[0], right: values[1]),
          gradientStops: [
            (color: AnthemTheme.primary.main, db: double.negativeInfinity),
            (color: AnthemTheme.primary.main, db: 0),
            (db: 0.0, color: AnthemTheme.meter.clipping),
            (db: 12.0, color: AnthemTheme.meter.clipping),
          ],
          timestamp: leftTime.compareTo(rightTime) >= 0 ? leftTime : rightTime,
        );
      },
    );
  }
}

class _TrackControlButtons extends StatelessWidget {
  const _TrackControlButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        SizedBox(
          height: 20,
          child: ButtonGroup(
            expandChildren: true,
            children: [
              Button(
                consumePress: true,
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
              Button(
                consumePress: true,
                contentPadding: .all(4),
                icon: Icons.solo,
              ),
              Button(
                consumePress: true,
                contentPadding: .all(4),
                icon: Icons.mute,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
