/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:math' as math;
import 'dart:math';

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/editors/mixer/mixer_strip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

const _scrollbarShortSideLength = 17.0;

class Mixer extends StatefulObserverWidget {
  const Mixer({super.key});

  @override
  State<Mixer> createState() => _MixerState();
}

class _MixerState extends State<Mixer> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final trackController = serviceRegistry.trackController;

    final tracks = trackController.getTracksIterable().toList();

    final firstSendTrackIndex = () {
      for (var i = 0; i < tracks.length; i++) {
        final (_, isSendTrack, _) = tracks[i];
        if (isSendTrack) {
          return i;
        }
      }

      throw StateError(
        'Mixer.dart build(): Failed to find at least one send track. There must'
        ' always be at least a master track.',
      );
    }();

    final maxDepth = tracks.fold(0, (currentDepth, trackInfo) {
      final (_, _, thisTrackDepth) = trackInfo;
      return max(currentDepth, thisTrackDepth);
    });

    final regularTrackCount = firstSendTrackIndex;
    final sendTrackCount = tracks.length - regularTrackCount;

    return ColoredBox(
      color: AnthemTheme.panel.backgroundDark,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalTrackWidth = tracks.length * mixerStripTotalWidth;
          final remainingGapWidth = constraints.maxWidth - totalTrackWidth;
          final scrollRegionEnd = math.max(
            constraints.maxWidth,
            totalTrackWidth,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  scrollDirection: .horizontal,
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => MixerStrip(
                          trackId: tracks[index].$1,
                          hasStartBorder: index != 0,
                          hasEndBorder: index == regularTrackCount - 1,
                          maxTrackDepth: maxDepth,
                        ),
                        childCount: regularTrackCount,
                      ),
                    ),

                    if (remainingGapWidth > 0)
                      SliverToBoxAdapter(
                        child: SizedBox(width: remainingGapWidth),
                      ),

                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => MixerStrip(
                          trackId: tracks[regularTrackCount + index].$1,
                          hasStartBorder: true,
                          hasEndBorder: index != sendTrackCount - 1,
                          maxTrackDepth: maxDepth,
                        ),
                        childCount: sendTrackCount,
                      ),
                    ),
                  ],
                ),
              ),
              _HorizontalScrollbar(
                scrollController: _scrollController,
                scrollRegionEnd: scrollRegionEnd,
                viewportWidth: constraints.maxWidth,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HorizontalScrollbar extends StatelessWidget {
  final ScrollController scrollController;
  final double scrollRegionEnd;
  final double viewportWidth;

  const _HorizontalScrollbar({
    required this.scrollController,
    required this.scrollRegionEnd,
    required this.viewportWidth,
  });

  @override
  Widget build(BuildContext context) {
    final maxScrollOffset = math.max(0.0, scrollRegionEnd - viewportWidth);

    return Container(
      height: _scrollbarShortSideLength,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AnthemTheme.panel.border, width: 1),
        ),
        color: AnthemTheme.panel.background,
      ),
      child: AnimatedBuilder(
        animation: scrollController,
        builder: (context, child) {
          final scrollOffset = scrollController.hasClients
              ? scrollController.offset.clamp(0.0, maxScrollOffset).toDouble()
              : 0.0;

          return ScrollbarRenderer(
            scrollRegionStart: 0,
            scrollRegionEnd: scrollRegionEnd,
            handleStart: scrollOffset,
            handleEnd: scrollOffset + viewportWidth,
            onChange: (event) {
              if (!scrollController.hasClients) {
                return;
              }

              scrollController.jumpTo(
                event.handleStart.clamp(0.0, maxScrollOffset).toDouble(),
              );
            },
          );
        },
      ),
    );
  }
}
