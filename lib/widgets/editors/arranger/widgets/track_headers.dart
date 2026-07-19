/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/hint/hint.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/arranger/scroll_manager.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'track_header.dart';
import 'track_header_resize.dart';

const _dividerHitPadding = 5.0;
const _addTrackButtonSize = 20.0;
const _addTrackButtonSpacing = 8.0;

/// Paints the color assigned to a row or group of rows.
class TrackColorIndicator extends StatelessWidget {
  final Color color;

  const TrackColorIndicator({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border(
          right: BorderSide(color: AnthemTheme.panel.border, width: 1),
        ),
      ),
    );
  }
}

/// Paints and handles interaction for one calculated track divider.
class TrackDivider extends StatefulObserverWidget {
  final TrackDividerLayout layout;
  final double trackHeight;
  final double visualTop;

  const TrackDivider({
    super.key,
    required this.layout,
    required this.trackHeight,
    required this.visualTop,
  });

  @override
  State<TrackDivider> createState() => _TrackDividerState();
}

class _TrackDividerState extends State<TrackDivider> {
  double? _initialPixelHeight;
  double? _initialModifier;
  double? _initialVerticalScrollPosition;
  TrackHeaderResizeDragState? _dragState;
  CursorOverrideHandle? _cursorOverrideHandle;

  @override
  void dispose() {
    _clearResizeCursorOverride();
    super.dispose();
  }

  void _setResizeCursorOverride() {
    _cursorOverrideHandle?.close();
    _cursorOverrideHandle = ServiceRegistry.mainWindowController
        .pushCursorOverride(SystemMouseCursors.resizeUpDown);
  }

  void _clearResizeCursorOverride() {
    _cursorOverrideHandle?.close();
    _cursorOverrideHandle = null;
  }

  void _endResize() {
    _initialPixelHeight = null;
    _initialModifier = null;
    _initialVerticalScrollPosition = null;
    _dragState = null;
    _clearResizeCursorOverride();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);
    final resizedRowId = widget.layout.resizedRowId;
    final resizesFromTop = widget.layout.resizeEdge == TrackResizeEdge.top;
    final trackHeightModifier = viewModel.rowHeightModifier(resizedRowId);

    return Hint(
      overrideWhilePressed: true,
      hint: [
        .new('click + drag', 'Resize'),
        .new('right click', 'Insert track...'),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          onDoubleTap: () {
            viewModel.resetRowHeightModifier(resizedRowId);
            viewModel.refreshTrackLayout(
              viewModel.editorHeight,
              headerWidth: viewModel.trackLayout.headerWidth,
            );
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _initialPixelHeight = widget.trackHeight;
              _initialModifier = trackHeightModifier;
              _initialVerticalScrollPosition = viewModel.verticalScrollPosition;
              _dragState = TrackHeaderResizeDragState.initial(
                pointerY: event.position.dy,
                initialModifier: trackHeightModifier,
              );

              _setResizeCursorOverride();
            },
            onPointerMove: (event) {
              final initialPixelHeight = _initialPixelHeight;
              final initialModifier = _initialModifier;
              final initialVerticalScrollPosition =
                  _initialVerticalScrollPosition;
              final dragState = _dragState;
              if (initialPixelHeight == null ||
                  initialModifier == null ||
                  initialVerticalScrollPosition == null ||
                  dragState == null) {
                return;
              }

              final resizeResult = calculateTrackHeaderResize(
                initialPixelHeight: initialPixelHeight,
                initialModifier: initialModifier,
                pointerY: event.position.dy,
                isSendTrack: resizesFromTop,
                state: dragState,
              );
              _dragState = resizeResult.state;

              viewModel.setRowHeightModifier(
                resizedRowId,
                resizeResult.modifier,
              );

              if (resizesFromTop && viewModel.regularToSendGapHeight == 0) {
                viewModel.verticalScrollPosition =
                    (initialVerticalScrollPosition +
                            (resizeResult.pixelHeight - initialPixelHeight))
                        .clamp(0, viewModel.maxVerticalScrollPosition);
              }

              viewModel.refreshTrackLayout(
                viewModel.editorHeight,
                headerWidth: viewModel.trackLayout.headerWidth,
              );
            },
            onPointerUp: (_) => _endResize(),
            onPointerCancel: (_) => _endResize(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: widget.visualTop,
                  height: widget.layout.bounds.height,
                  child: ColoredBox(
                    key: Key('$resizedRowId-divider-visual'),
                    color: AnthemTheme.panel.border,
                  ),
                ),
              ],
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
  final _menuController = AnthemMenuController();

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final viewModel = serviceRegistry.arrangerViewModel;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListenableBuilder(
          listenable: viewModel.trackLayout.layoutRevision,
          builder: (context, child) => Observer(
            builder: (context) {
              final layout = viewModel.trackLayout;
              final scrollOffset = widget.verticalScrollPosition;
              final viewportBottom = scrollOffset + constraints.maxHeight;

              bool isVisible(Rect bounds) =>
                  bounds.bottom > scrollOffset && bounds.top < viewportBottom;

              final baseBounds = <Object, Rect>{};
              final baseChildren = <Widget>[];

              for (final indicator in layout.colorIndicatorLayouts) {
                if (!isVisible(indicator.bounds)) continue;

                final row = layout.rowLayoutForId(indicator.rowId).row;
                final color = switch (row) {
                  ProjectTrackRow(:final trackId) =>
                    project.tracks[trackId]?.color.colorShifter.clipBase
                        .toColor(),
                  PhantomAutomationTrackRow(:final phantomLane) =>
                    project
                        .tracks[phantomLane.parentTrackId]
                        ?.color
                        .colorShifter
                        .clipBase
                        .toColor()
                        .withValues(alpha: 0.45),
                };
                if (color == null) continue;
                final childId = ('indicator', indicator.rowId);
                baseBounds[childId] = indicator.bounds;
                baseChildren.add(
                  LayoutId(
                    id: childId,
                    child: TrackColorIndicator(
                      key: Key('${row.rowId}-indicator'),
                      color: color,
                    ),
                  ),
                );
              }

              for (final rowLayout in layout.rowLayouts) {
                if (!isVisible(rowLayout.headerBounds)) continue;

                final row = rowLayout.row;
                if (row case ProjectTrackRow(
                  :final trackId,
                ) when !project.tracks.containsKey(trackId)) {
                  continue;
                }
                final childId = ('header', row.rowId);
                baseBounds[childId] = rowLayout.headerBounds;
                baseChildren.add(
                  LayoutId(
                    id: childId,
                    child: switch (row) {
                      ProjectTrackRow(:final trackId) => TrackHeaderContent(
                        key: Key(trackId.toString()),
                        trackId: trackId,
                      ),
                      PhantomAutomationTrackRow(:final phantomLane) =>
                        PhantomAutomationTrackHeaderContent(
                          key: Key('phantom-${phantomLane.id}'),
                          phantomLane: phantomLane,
                        ),
                    },
                  ),
                );
              }

              final addTrackSpan = layout.addTrackControlSpan;
              final addTrackBounds = Rect.fromLTWH(
                _addTrackButtonSpacing,
                addTrackSpan.top + _addTrackButtonSpacing,
                _addTrackButtonSize,
                _addTrackButtonSize,
              );
              if (isVisible(addTrackBounds)) {
                const childId = 'add-track-button';
                baseBounds[childId] = addTrackBounds;
                baseChildren.add(
                  LayoutId(
                    id: childId,
                    child: Menu(
                      menuController: _menuController,
                      menuDef: .new(
                        children: [
                          AnthemMenuItem(
                            text: 'Add track',
                            onSelected: () {
                              serviceRegistry.trackController.addTrack();
                            },
                          ),
                          AnthemMenuItem(
                            text: 'Add send track',
                            onSelected: () {
                              serviceRegistry.trackController.addSendTrack();
                            },
                          ),
                        ],
                      ),
                      child: Button(
                        key: const Key('add-track-button'),
                        icon: Icons.add,
                        hint: [.new('click', 'Add a new track...')],
                        onPress: _menuController.toggle,
                        contentPadding: .zero,
                        variant: .outline,
                      ),
                    ),
                  ),
                );
              }

              final dividerBounds = <Object, Rect>{};
              final dividerChildren = <Widget>[];
              for (final divider in layout.dividerLayouts) {
                final interactionBounds = Rect.fromLTRB(
                  divider.bounds.left,
                  divider.bounds.top - _dividerHitPadding,
                  divider.bounds.right,
                  divider.bounds.bottom + _dividerHitPadding,
                );
                if (!isVisible(interactionBounds)) continue;

                final childId = ('divider', divider.resizedRowId);
                final rowLayout = layout.rowLayoutForId(divider.resizedRowId);
                if (rowLayout.row case ProjectTrackRow(
                  :final trackId,
                ) when !project.tracks.containsKey(trackId)) {
                  continue;
                }
                final rowKey = switch (rowLayout.row) {
                  ProjectTrackRow(:final trackId) => trackId.toString(),
                  PhantomAutomationTrackRow(:final phantomLane) =>
                    'phantom-${phantomLane.id}',
                };
                dividerBounds[childId] = interactionBounds;
                dividerChildren.add(
                  LayoutId(
                    id: childId,
                    child: TrackDivider(
                      key: Key('$rowKey-handle'),
                      layout: divider,
                      trackHeight: rowLayout.contentSpan.height,
                      visualTop: divider.bounds.top - interactionBounds.top,
                    ),
                  ),
                );
              }

              final revision = layout.layoutRevision.value;
              return ArrangerScrollManager.verticalOnly(
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomMultiChildLayout(
                        delegate: _TrackHeaderLayoutDelegate(
                          boundsById: baseBounds,
                          scrollOffset: scrollOffset,
                          layoutRevision: revision,
                        ),
                        children: baseChildren,
                      ),
                      CustomMultiChildLayout(
                        delegate: _TrackHeaderLayoutDelegate(
                          boundsById: dividerBounds,
                          scrollOffset: scrollOffset,
                          layoutRevision: revision,
                        ),
                        children: dividerChildren,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TrackHeaderLayoutDelegate extends MultiChildLayoutDelegate {
  final Map<Object, Rect> boundsById;
  final double scrollOffset;
  final int layoutRevision;

  _TrackHeaderLayoutDelegate({
    required this.boundsById,
    required this.scrollOffset,
    required this.layoutRevision,
  });

  @override
  void performLayout(Size size) {
    for (final MapEntry(key: childId, value: bounds) in boundsById.entries) {
      if (!hasChild(childId)) continue;

      layoutChild(childId, BoxConstraints.tight(bounds.size));
      positionChild(childId, Offset(bounds.left, bounds.top - scrollOffset));
    }
  }

  @override
  bool shouldRelayout(covariant _TrackHeaderLayoutDelegate oldDelegate) {
    return oldDelegate.layoutRevision != layoutRevision ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.boundsById.length != boundsById.length;
  }
}
