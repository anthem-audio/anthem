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
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/hint/hint.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class _TrackHeader extends StatelessObserverWidget {
  final Id trackID;

  const _TrackHeader({required this.trackID});

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final track = project.tracks[trackID]!;

    final trackAnthemColor = track.color;
    final colorShifter = trackAnthemColor.colorShifter;
    final color = colorShifter.clipBase.toColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: AnthemTheme.panel.main,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 9,
                decoration: BoxDecoration(
                  color: color,
                  border: Border(
                    right: BorderSide(
                      color: AnthemTheme.panel.border,
                      width: 1,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Text(
                    track.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AnthemTheme.text.main,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackHeaderResizeHandle extends StatefulObserverWidget {
  final double resizeHandleHeight;
  final String trackId;
  final double trackHeight;
  final bool isSendTrack;

  const _TrackHeaderResizeHandle({
    required this.resizeHandleHeight,
    required this.trackId,
    required this.trackHeight,
    required this.isSendTrack,
  });

  @override
  State<_TrackHeaderResizeHandle> createState() =>
      _TrackHeaderResizeHandleState();
}

class _TrackHeaderResizeHandleState extends State<_TrackHeaderResizeHandle> {
  double startPixelHeight = -1;
  double startModifier = -1;
  double startY = -1;
  double startVerticalScrollPosition = -1;

  double lastModifier = -1;
  double lastPixelHeight = -1;
  double deadZoneAmountTraveled = -1;
  bool shouldIgnoreDeadZone = false;

  // Dead zone at a height modifier of 1.0, which makes it easier to
  // reset track height
  static const deadZoneSize = 5.0;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);

    final trackHeightModifier = viewModel.trackHeightModifiers[widget.trackId]!;

    return SizedBox(
      height: widget.resizeHandleHeight,
      child: Hint(
        hint: [
          .new('click + drag', 'Resize'),
          .new('right click', 'Insert track...'),
        ],
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            onDoubleTap: () {
              // On double click, this resets the track height
              viewModel.trackHeightModifiers[widget.trackId] = 1;

              // This may require scrolling, as a shorter track may mean that the
              // bottom of the lowest track is now above the bottom of the editor.
              // This will be recalculated regardless on next render, but we would
              // render a single frame incorrectly which is noticeable.
              // Recalculating here means everything is correct on next render.
              viewModel.trackPositionCalculator.invalidate(
                viewModel.editorHeight,
              );
            },
            child: Listener(
              onPointerDown: (event) {
                startPixelHeight = lastPixelHeight = widget.trackHeight;
                startModifier = lastModifier = trackHeightModifier;
                // If we start exactly at 1.0, we ignore the sticky effect
                // initially
                shouldIgnoreDeadZone = startModifier == 1;
                startY = event.position.dy;
                startVerticalScrollPosition = viewModel.verticalScrollPosition;
              },
              onPointerMove: (event) {
                // Compute raw delta in pixels based on pointer movement
                final direction = widget.isSendTrack ? -1.0 : 1.0;
                var deltaPixelsRaw = direction * (event.position.dy - startY);

                // Raw (no dead-zone) pixel height and modifier
                var rawPixelHeight = (startPixelHeight + deltaPixelsRaw).clamp(
                  minTrackHeight,
                  maxTrackHeight,
                );
                var rawModifier =
                    rawPixelHeight / startPixelHeight * startModifier;

                assert(startModifier > 0);

                final crossingOffset =
                    startPixelHeight * (1 / startModifier - 1);
                var distanceFromCrossing = deltaPixelsRaw - crossingOffset;

                final withinDeadZone =
                    distanceFromCrossing.abs() <= deadZoneSize;

                // This transitions from the "dead zone suppressed" handling in
                // the else case below, to regular handling.
                if (shouldIgnoreDeadZone && !withinDeadZone) {
                  // The user has dragged OUT of the dead zone. We now disable the
                  // "ignore" flag so that if they return, it will stick.
                  shouldIgnoreDeadZone = false;

                  // Hack: To prevent a snap (jump in height), we must offset the
                  // startY. Standard logic subtracts `deadZoneSize` from the
                  // delta. We shift startY in the opposite direction so the
                  // resulting delta is larger, counteracting the subtraction.
                  final offset =
                      distanceFromCrossing.sign * deadZoneSize * direction;
                  startY -= offset;

                  // Recalculate delta and raw values based on the new startY
                  deltaPixelsRaw = direction * (event.position.dy - startY);
                  rawPixelHeight = (startPixelHeight + deltaPixelsRaw).clamp(
                    minTrackHeight,
                    maxTrackHeight,
                  );
                  rawModifier =
                      rawPixelHeight / startPixelHeight * startModifier;
                  distanceFromCrossing = deltaPixelsRaw - crossingOffset;
                }

                double newPixelHeight;
                double newModifier;

                if (!shouldIgnoreDeadZone && withinDeadZone) {
                  // Inside dead-zone: hold at modifier == 1.0
                  newPixelHeight = (startPixelHeight / startModifier).clamp(
                    minTrackHeight,
                    maxTrackHeight,
                  );
                  deadZoneAmountTraveled = distanceFromCrossing;
                  newModifier =
                      newPixelHeight / startPixelHeight * startModifier;
                } else if (!shouldIgnoreDeadZone && !withinDeadZone) {
                  // Past the dead-zone: subtract its width to keep continuity
                  final effectiveDelta =
                      deltaPixelsRaw - distanceFromCrossing.sign * deadZoneSize;
                  newPixelHeight = (startPixelHeight + effectiveDelta).clamp(
                    minTrackHeight,
                    maxTrackHeight,
                  );
                  newModifier =
                      newPixelHeight / startPixelHeight * startModifier;
                } else {
                  // Dead-zone suppressed (starting at 1 and moving away)
                  newPixelHeight = rawPixelHeight;
                  newModifier = rawModifier;
                }

                viewModel.trackHeightModifiers[widget.trackId] = newModifier;

                if (widget.isSendTrack &&
                    viewModel.regularToSendGapHeight == 0) {
                  viewModel.verticalScrollPosition =
                      (startVerticalScrollPosition +
                              (newPixelHeight - startPixelHeight))
                          .clamp(
                            0,
                            viewModel.scrollAreaHeight - viewModel.editorHeight,
                          );
                }

                // We also need to invalidate here (see invalidate call above for
                // context)
                viewModel.trackPositionCalculator.invalidate(
                  viewModel.editorHeight,
                );

                lastModifier = newModifier;
                lastPixelHeight = newPixelHeight;
              },
              // Hack: Listener callbacks do nothing unless this is here
              child: Container(color: const Color(0x00000000)),
            ),
          ),
        ),
      ),
    );
  }
}

class TrackHeaders extends StatefulWidget {
  final double verticalScrollPosition;

  const TrackHeaders({super.key, required this.verticalScrollPosition});

  @override
  State<TrackHeaders> createState() => _TrackHeadersState();
}

class _TrackHeadersState extends State<TrackHeaders> {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);
    final project = Provider.of<ProjectModel>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final editorHeight = constraints.maxHeight;

        return Observer(
          builder: (context) {
            List<Widget> headers = [];
            List<Widget> resizeHandles = [];

            double positionForAddButton = double.nan;
            var lastTrackWasSendTrack = false;
            var lastTrackBottom = 0.0;

            // For MobX, since we're pulling the real values from a cache
            final _ = viewModel.baseTrackHeight;

            for (final (trackIndex, (trackId, isSendTrack))
                in project.trackOrder
                    .map((t) => (t, false))
                    .followedBy(
                      project.sendTrackOrder.reversed.map((t) => (t, true)),
                    )
                    .indexed) {
              // For MobX, since we're pulling the real values from a cache
              final _ = viewModel.trackHeightModifiers[trackId];

              final trackPosition = viewModel.trackPositionCalculator
                  .getTrackPosition(trackIndex);
              final trackHeight = viewModel.trackPositionCalculator
                  .getTrackHeight(trackIndex);

              if (isSendTrack && !lastTrackWasSendTrack) {
                lastTrackWasSendTrack = true;
                positionForAddButton = lastTrackBottom;
              }

              lastTrackBottom = trackPosition + trackHeight;

              if (trackPosition >= editorHeight) {
                break;
              }

              if (trackPosition + trackHeight > 0) {
                headers.add(
                  Positioned(
                    key: Key(trackId),
                    top: trackPosition + (isSendTrack ? 1 : 0),
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: trackHeight - 1,
                      child: _TrackHeader(trackID: trackId),
                    ),
                  ),
                );
                headers.add(
                  Positioned(
                    key: Key('$trackId-border'),
                    top: trackPosition + (isSendTrack ? 0 : (trackHeight - 1)),
                    left: 0,
                    right: 0,
                    height: 1,
                    child: Container(color: AnthemTheme.panel.border),
                  ),
                );

                const resizeHandleHeight = 10.0;

                var resizeHandleTop =
                    trackPosition - 1 - resizeHandleHeight / 2;
                if (!isSendTrack) {
                  resizeHandleTop += trackHeight + 1;
                }

                resizeHandles.add(
                  Positioned(
                    key: Key('$trackId-handle'),
                    left: 0,
                    right: 0,
                    top: resizeHandleTop,
                    child: _TrackHeaderResizeHandle(
                      resizeHandleHeight: resizeHandleHeight,
                      trackHeight: trackHeight,
                      isSendTrack: isSendTrack,
                      trackId: trackId,
                    ),
                  ),
                );
              }
            }

            // If we didn't fill the whole area, then we are at the end of the
            // track list, so we can add an "add track" button
            if (!positionForAddButton.isNaN) {
              headers.add(
                Positioned(
                  key: Key('add-track-button'),
                  top: positionForAddButton + 8,
                  left: 16,
                  right: 16,
                  child: Button(
                    icon: Icons.add,
                    hint: [.new('click', 'Add a new track')],
                    onPress: () {
                      final controller = ServiceRegistry.forProject(
                        project.id,
                      ).projectController;
                      controller.addTrack();
                    },
                  ),
                ),
              );
            }

            return ClipRect(child: Stack(children: headers + resizeHandles));
          },
        );
      },
    );
  }
}
