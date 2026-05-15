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
import 'package:anthem/model/processing_graph/processors/utility.dart';
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
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class TrackHeader extends StatefulObserverWidget {
  final Id trackId;

  const TrackHeader({super.key, required this.trackId});

  @override
  State<TrackHeader> createState() => _TrackHeaderState();
}

class _TrackHeaderState extends State<TrackHeader> {
  static const _doubleClickThreshold = Duration(milliseconds: 500);
  static const _maxDoubleClickDistance = 8.0;

  Duration? _lastPrimaryTapTime;
  Offset? _lastPrimaryTapPosition;

  @override
  void didUpdateWidget(covariant TrackHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.trackId != widget.trackId) {
      _clearPrimaryTap();
    }
  }

  bool _isDoubleClick(Offset position, Duration tapTime) {
    final lastTapTime = _lastPrimaryTapTime;
    final lastTapPosition = _lastPrimaryTapPosition;

    if (lastTapTime == null || lastTapPosition == null) {
      return false;
    }

    final timeDelta = tapTime - lastTapTime;
    final distance = (position - lastTapPosition).distance;

    return timeDelta <= _doubleClickThreshold &&
        distance <= _maxDoubleClickDistance;
  }

  void _recordPrimaryTap(Offset position, Duration tapTime) {
    _lastPrimaryTapPosition = position;
    _lastPrimaryTapTime = tapTime;
  }

  void _clearPrimaryTap() {
    _lastPrimaryTapPosition = null;
    _lastPrimaryTapTime = null;
  }

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final projectServices = ServiceRegistry.forProject(project.id);
    final projectController = projectServices.projectController;
    final trackController = projectServices.trackController;
    final track = project.tracks[widget.trackId]!;

    final controller = projectServices.arrangerController;
    final viewModel = projectServices.arrangerViewModel;

    final trackAnthemColor = track.color;
    final colorShifter = trackAnthemColor.colorShifter;
    final color = colorShifter.clipBase.toColor();

    final trackBackgroundColor = viewModel.selectedTracks.contains(track.id)
        ? AnthemTheme.panel.borderLight
        : AnthemTheme.panel.main;

    final trackHeight = viewModel.trackPositionCalculator.getTrackHeight(
      viewModel.trackPositionCalculator.trackIdToIndex(widget.trackId),
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

    void onPrimaryTapUp(TapUpDetails e) {
      onClick();

      final tapTime = SchedulerBinding.instance.currentSystemFrameTimeStamp;
      if (_isDoubleClick(e.globalPosition, tapTime)) {
        _clearPrimaryTap();
        projectController.setActiveEditor(editor: EditorKind.deviceRack);
        return;
      }

      _recordPrimaryTap(e.globalPosition, tapTime);
    }

    void onSecondaryClick(TapUpDetails e) {
      _clearPrimaryTap();

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
      child: GestureDetector(
        onTapUp: onPrimaryTapUp,
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
                                  track.utilityNode
                                      ?.getPortById(
                                        UtilityProcessorModel.gainPortId,
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
                                final node = track.utilityNode;
                                if (node == null) return;

                                node
                                        .getPortById(
                                          UtilityProcessorModel.gainPortId,
                                        )
                                        .parameterValue =
                                    value;
                              },
                            ),
                          if (height >= heightThreshold2)
                            Slider(
                              value: UtilityProcessorModel.parameterValueToPan(
                                track.utilityNode
                                        ?.getPortById(
                                          UtilityProcessorModel.balancePortId,
                                        )
                                        .parameterValue ??
                                    UtilityProcessorModel.panToParameterValue(
                                      0,
                                    ),
                              ),
                              min: -1,
                              max: 1,
                              height: 20,
                              borderRadius: 4,
                              type: .pan,
                              stickyPoints: [0],
                              hint: (v) =>
                                  'Track balance: ${UtilityProcessorModel.parameterValueToString(UtilityProcessorModel.panToParameterValue(v))}',
                              onValueChanged: (value) {
                                final node = track.utilityNode;
                                if (node == null) return;

                                node
                                        .getPortById(
                                          UtilityProcessorModel.balancePortId,
                                        )
                                        .parameterValue =
                                    UtilityProcessorModel.panToParameterValue(
                                      value,
                                    );
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
    final visualizationIds = track.dbMeterVisualizationIds.toList(
      growable: false,
    );
    if (visualizationIds.length < 2) {
      return const SizedBox.expand();
    }

    return Meter(
      configs: (
        left: VisualizationSubscriptionConfig.max(
          visualizationIds[0],
          bufferMode: VisualizationBufferMode.adaptive,
        ),
        right: VisualizationSubscriptionConfig.max(
          visualizationIds[1],
          bufferMode: VisualizationBufferMode.adaptive,
        ),
      ),
      noBackground: true,
      gradientStops: [
        (color: AnthemTheme.primary.main, db: double.negativeInfinity),
        (color: AnthemTheme.primary.main, db: 0),
        (db: 0.0, color: AnthemTheme.meter.clipping),
        (db: 12.0, color: AnthemTheme.meter.clipping),
      ],
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
