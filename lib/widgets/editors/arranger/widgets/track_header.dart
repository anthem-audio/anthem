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
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class TrackHeader extends StatelessObserverWidget {
  final Id trackID;

  const TrackHeader({super.key, required this.trackID});

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

class TrackHeaderResizeHandle extends StatefulObserverWidget {
  final double resizeHandleHeight;
  final String trackId;
  final double trackHeight;
  final bool isSendTrack;

  const TrackHeaderResizeHandle({
    super.key,
    required this.resizeHandleHeight,
    required this.trackId,
    required this.trackHeight,
    required this.isSendTrack,
  });

  @override
  State<TrackHeaderResizeHandle> createState() =>
      _TrackHeaderResizeHandleState();
}

class _TrackHeaderResizeHandleState extends State<TrackHeaderResizeHandle> {
  double startPixelHeight = -1;
  double startModifier = -1;
  double startY = -1;
  double startVerticalScrollPosition = -1;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);

    final trackHeightModifier = viewModel.trackHeightModifiers[widget.trackId]!;

    return SizedBox(
      height: widget.resizeHandleHeight,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: Listener(
          onPointerDown: (event) {
            startPixelHeight = widget.trackHeight;
            startModifier = trackHeightModifier;
            startY = event.position.dy;
            startVerticalScrollPosition = viewModel.verticalScrollPosition;
          },
          onPointerMove: (event) {
            final newPixelHeight =
                ((widget.isSendTrack ? -1.0 : 1.0) *
                            (event.position.dy - startY) +
                        startPixelHeight)
                    .clamp(minTrackHeight, maxTrackHeight);
            final newModifier =
                newPixelHeight / startPixelHeight * startModifier;
            viewModel.trackHeightModifiers[widget.trackId] = newModifier;

            if (widget.isSendTrack && viewModel.regularToSendGapHeight == 0) {
              viewModel.verticalScrollPosition =
                  (startVerticalScrollPosition +
                          (newPixelHeight - startPixelHeight))
                      .clamp(
                        0,
                        viewModel.scrollAreaHeight - viewModel.editorHeight,
                      );
            }
          },
          // Hack: Listener callbacks do nothing unless this is here
          child: Container(color: const Color(0x00000000)),
        ),
      ),
    );
  }
}
