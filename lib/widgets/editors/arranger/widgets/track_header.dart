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
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_header_content_layout.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class TrackHeaderContent extends StatefulObserverWidget {
  final Id trackId;

  const TrackHeaderContent({super.key, required this.trackId});

  @override
  State<TrackHeaderContent> createState() => _TrackHeaderContentState();
}

const _trackMeterWidth = 15.0;

class _TrackHeaderContentState extends State<TrackHeaderContent> {
  static const _doubleClickThreshold = Duration(milliseconds: 500);
  static const _maxDoubleClickDistance = 8.0;

  Duration? _lastPrimaryTapTime;
  Offset? _lastPrimaryTapPosition;

  @override
  void didUpdateWidget(covariant TrackHeaderContent oldWidget) {
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
    final isSendTrack = trackController.isSendTrack(track.id);

    final controller = projectServices.arrangerController;
    final viewModel = projectServices.arrangerViewModel;

    final trackBackgroundColor = viewModel.selectedTracks.contains(track.id)
        ? AnthemTheme.panel.borderLight
        : AnthemTheme.panel.main;

    void onClick() {
      if (HardwareKeyboard.instance.isShiftPressed) {
        controller.shiftClickToTrack(track.id);
        return;
      }

      if (isPrimaryModifierPressed(HardwareKeyboard.instance)) {
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
        if (track.hasProcessing) {
          projectController.setActiveEditor(editor: EditorKind.deviceRack);
        }
        return;
      }

      _recordPrimaryTap(e.globalPosition, tapTime);
    }

    void onSecondaryClick(TapUpDetails e) {
      _clearPrimaryTap();

      if (!controller.isTrackSelected(track.id)) {
        controller.selectTrack(track.id);
      }

      final menuItems = track.isAutomationLane
          ? [
              AnthemMenuItem(
                text: 'Delete',
                hint: 'Delete this automation lane',
                onSelected: () {
                  trackController.removeAutomationLane(track.id);
                },
              ),
            ]
          : [
              AnthemMenuItem(
                text: 'Insert track',
                hint: track.type == .group
                    ? 'Add a track at the end of this group'
                    : isSendTrack
                    ? 'Insert a track above this track'
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
                    (t) =>
                        project.tracks[t]?.isMasterTrack == true ||
                        project.tracks[t]?.isAutomationLane == true,
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
            ];

      openContextMenu(e.globalPosition, MenuDef(children: menuItems));
    }

    return GestureDetector(
      onTapUp: onPrimaryTapUp,
      onSecondaryTapUp: onSecondaryClick,
      child: Container(
        color: trackBackgroundColor,
        child: _TrackContent(track: track),
      ),
    );
  }
}

class PhantomAutomationTrackHeaderContent extends StatelessWidget {
  final PhantomAutomationLaneInfo phantomLane;

  const PhantomAutomationTrackHeaderContent({
    super.key,
    required this.phantomLane,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final projectServices = ServiceRegistry.forProject(project.id);
    final controller = projectServices.arrangerController;
    final target = phantomLane.target;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentLayout = calculateTrackHeaderContentLayout(
          headerHeight: constraints.maxHeight,
          isAutomationLane: true,
        );

        return Container(
          color: AnthemTheme.panel.main,
          padding: trackHeaderContentPadding,
          child: Row(
            spacing: 4,
            children: [
              Expanded(
                child: _AutomationTargetLabel(
                  title: target?.parameterName ?? phantomLane.title,
                  subtitle: target?.ownerName,
                  isPlaceholder: target == null,
                  compact: contentLayout.size == TrackHeaderSize.compact,
                ),
              ),
              if (target != null)
                Button(
                  consumePress: true,
                  contentPadding: const EdgeInsets.all(2),
                  height: 20,
                  width: 20,
                  icon: Icons.add,
                  hint: [.new('click', 'Create automation lane')],
                  onPress: () {
                    controller.createAutomationLaneForTarget(target);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AutomationTargetLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isPlaceholder;
  final bool compact;

  const _AutomationTargetLabel({
    required this.title,
    this.subtitle,
    this.isPlaceholder = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: isPlaceholder ? AnthemTheme.text.disabled : AnthemTheme.text.main,
      fontSize: 11,
      fontStyle: isPlaceholder ? FontStyle.italic : null,
      fontWeight: .w500,
    );
    final subtitleStyle = TextStyle(
      color: AnthemTheme.text.disabled,
      fontSize: compact ? 11 : 10,
      fontStyle: isPlaceholder ? FontStyle.italic : null,
    );
    final subtitle = this.subtitle;

    if (compact) {
      return Text.rich(
        TextSpan(
          text: title,
          style: titleStyle,
          children: [
            if (subtitle != null) ...[
              const TextSpan(text: '  '),
              TextSpan(text: subtitle, style: subtitleStyle),
            ],
          ],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
      );
    }

    if (subtitle == null) {
      return Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
        style: titleStyle,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
          style: titleStyle,
        ),
        Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
          style: subtitleStyle,
        ),
      ],
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
        final contentLayout = calculateTrackHeaderContentLayout(
          headerHeight: height,
          isAutomationLane: track.isAutomationLane,
        );

        return Padding(
          padding: trackHeaderContentPadding,
          child: Center(
            child: _TrackContentRow(track: track, contentLayout: contentLayout),
          ),
        );
      },
    );
  }
}

class _TrackContentRow extends StatelessObserverWidget {
  final TrackModel track;
  final TrackHeaderContentLayout contentLayout;

  const _TrackContentRow({required this.track, required this.contentLayout});

  @override
  Widget build(BuildContext context) {
    final headerSize = contentLayout.size;
    final project = Provider.of<ProjectModel>(context);
    final processing = track.processing;
    final automationTarget = track.automationTarget;
    final AutomationParameterTarget? resolvedAutomationTarget;
    if (track.isAutomationLane && automationTarget != null) {
      final controller = ServiceRegistry.forProject(
        project.id,
      ).arrangerController;
      resolvedAutomationTarget = controller.resolveAutomationTarget(
        nodeId: automationTarget.nodeId,
        portId: automationTarget.portId,
      );
    } else {
      resolvedAutomationTarget = null;
    }
    final automationTargetNode = resolvedAutomationTarget == null
        ? null
        : project.processingGraph.nodes[resolvedAutomationTarget.nodeId];
    final automationParameter = automationTargetNode == null
        ? null
        : ParameterUiBinding.byId(
            node: automationTargetNode,
            portId: resolvedAutomationTarget!.portId,
          );
    final utilityNode = processing?.utilityNode;
    final gainParameter = utilityNode == null
        ? null
        : ParameterUiBinding.byId(
            node: utilityNode,
            portId: UtilityProcessorModel.gainPortId,
          );
    final balanceParameter = utilityNode == null
        ? null
        : ParameterUiBinding.byId(
            node: utilityNode,
            portId: UtilityProcessorModel.balancePortId,
            parameterToUiValue: UtilityProcessorModel.parameterValueToPan,
            uiToParameterValue: UtilityProcessorModel.panToParameterValue,
          );

    return Row(
      crossAxisAlignment:
          track.isAutomationLane || headerSize == TrackHeaderSize.compact
          ? .center
          : .start,
      spacing: 4,
      children: [
        Expanded(
          child: track.isAutomationLane
              ? _AutomationTargetLabel(
                  title: track.name,
                  subtitle: resolvedAutomationTarget?.ownerName,
                  compact: headerSize == TrackHeaderSize.compact,
                )
              : Text(
                  track.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: headerSize == TrackHeaderSize.compact ? 1 : 2,
                  style: TextStyle(
                    color: AnthemTheme.text.main,
                    fontSize: 11,
                    fontWeight: .w500,
                  ),
                ),
        ),
        if (track.isAutomationLane && automationParameter != null)
          Slider(
            parameter: automationParameter,
            axis: .vertical,
            width: _trackMeterWidth,
            height: contentLayout.height,
            borderRadius: 2,
          )
        else if (processing != null) ...[
          SizedBox(
            width: 70,
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              spacing: 4,
              children: [
                _TrackControlButtons(),
                if (headerSize != TrackHeaderSize.compact &&
                    gainParameter != null)
                  Slider(
                    parameter: gainParameter,
                    min: 0,
                    max: 1,
                    height: 20,
                    borderRadius: 4,
                    stickyPoints: [gainParameterZeroDbNormalized],
                    hint: (v) => 'Track gain: ${gainParameterValueToString(v)}',
                  ),
                if (headerSize == TrackHeaderSize.tall &&
                    balanceParameter != null)
                  Slider(
                    parameter: balanceParameter,
                    min: -1,
                    max: 1,
                    height: 20,
                    borderRadius: 4,
                    type: .pan,
                    stickyPoints: [0],
                    hint: (v) =>
                        'Track balance: ${UtilityProcessorModel.parameterValueToString(UtilityProcessorModel.panToParameterValue(v))}',
                  ),
              ],
            ),
          ),
          Container(
            width: _trackMeterWidth,
            // This is a bit ugly but avoids an IntrinsicHeight, which the
            // docs say is slow, and I don't really want to find out why
            height: contentLayout.height,
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
      ],
    );
  }
}

class _TrackDbMeter extends StatelessWidget {
  final TrackModel track;

  const _TrackDbMeter({required this.track});

  @override
  Widget build(BuildContext context) {
    final processing = track.processing;
    if (processing == null) {
      return const SizedBox.expand();
    }

    final visualizationIds = processing.dbMeterVisualizationIds.toList(
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
