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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'arranger_diagonal_pattern.dart';
import 'track_header_content_layout.dart';

const _extendedIndicatorColorWidth = 8.0;
const _buttonSize = 20.0;
const _buttonSpacing = 4.0;

/// Paints the color assigned to a row or group of rows.
class TrackColorIndicator extends StatelessObserverWidget {
  final Id trackId;
  final double trackHeight;
  final bool spansDescendants;
  final bool showButtonBorders;

  const TrackColorIndicator({
    super.key,
    required this.trackId,
    required this.trackHeight,
    required this.spansDescendants,
    this.showButtonBorders = false,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final track = project.tracks[trackId];
    if (track == null) return const SizedBox.shrink();

    final projectServices = ServiceRegistry.forProject(project.id);
    final viewModel = projectServices.arrangerViewModel;
    final groupExpanded = viewModel.isGroupExpanded(trackId);
    final automationExpanded =
        viewModel.automationExpandedByTrackId[trackId] ?? false;
    final hasAutomationLanes = track.automationLanes.isNotEmpty;
    final automationIcon = switch ((hasAutomationLanes, automationExpanded)) {
      (_, true) => Icons.track.automationExpanded,
      (true, false) => Icons.track.automationCollapsed,
      (false, false) => Icons.track.automationAdd,
    };

    final color = track.color.colorShifter.clipBase.toColor();
    final headerContentLayout = calculateTrackHeaderContentLayout(
      headerHeight: trackHeight,
      isAutomationLane: false,
    );

    var top = headerContentLayout.top;
    if (headerContentLayout.size != .compact) {
      // This centers the buttons with the text
      top -= 2;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border(
          right: BorderSide(color: AnthemTheme.panel.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: trackHeight,
            child: Stack(
              children: [
                Positioned(
                  left: trackHeaderContentPadding.left,
                  top: top,
                  child: Row(
                    spacing: _buttonSpacing,
                    children: [
                      Button(
                        variant: ButtonVariant.outline,
                        borderMatchesContent: true,
                        hideBorder:
                            !(track.type == .group && showButtonBorders),
                        consumePress: true,
                        contentPadding: const .all(0),
                        width: _buttonSize,
                        height: _buttonSize,
                        icon: switch (track.type) {
                          TrackType.normal => Icons.track.instrument,
                          TrackType.group =>
                            groupExpanded
                                ? Icons.track.folderOpen
                                : Icons.track.folderClosed,
                          TrackType.automationLane => throw StateError(
                            'Automation tracks do not support color indicators',
                          ),
                        },
                        interactable: track.type == .group,
                        hint: track.type == .group
                            ? [
                                .new(
                                  'click',
                                  groupExpanded
                                      ? 'Collapse track group'
                                      : 'Expand track group',
                                ),
                              ]
                            : null,
                        onPress: track.type == .group
                            ? () {
                                projectServices.arrangerController
                                    .toggleTrackGroupExpanded(trackId);
                              }
                            : null,
                      ),
                      Button(
                        variant: ButtonVariant.outline,
                        borderMatchesContent: true,
                        hideBorder: !showButtonBorders,
                        consumePress: true,
                        contentPadding: const .all(0),
                        width: _buttonSize,
                        height: _buttonSize,
                        icon: automationIcon,
                        hint: [
                          .new(
                            'click',
                            automationExpanded
                                ? 'Hide automation lanes'
                                : 'Show automation lanes',
                          ),
                        ],
                        onPress: () {
                          projectServices.arrangerController
                              .toggleTrackAutomationExpanded(trackId);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (spansDescendants)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AnthemTheme.panel.border,
                            width: 1,
                          ),
                          right: BorderSide(
                            color: AnthemTheme.panel.border,
                            width: 1,
                          ),
                        ),
                      ),
                      child: const ArrangerDiagonalPattern(),
                    ),
                  ),
                  const SizedBox(width: _extendedIndicatorColorWidth),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
