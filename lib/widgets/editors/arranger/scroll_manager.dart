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

import 'package:anthem/widgets/editors/shared/scroll_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'controller/arranger_controller.dart';
import 'helpers.dart';
import 'view_model.dart';

/// Adapts [EditorScrollManager] to the arranger's vertical track-space.
///
/// The arranger canvas uses [ArrangerScrollManager.editor] to get full editor
/// scrolling, including horizontal timeline movement and middle-mouse panning.
/// Non-canvas arranger surfaces, such as track headers, use
/// [ArrangerScrollManager.verticalOnly] so wheel and Alt-wheel input share the
/// same vertical scroll and track-height zoom behavior without enabling
/// horizontal timeline movement there.
class ArrangerScrollManager extends StatefulWidget {
  final Widget? child;
  final _ArrangerScrollManagerMode _mode;

  const ArrangerScrollManager.editor({super.key, this.child})
    : _mode = _ArrangerScrollManagerMode.editor;

  const ArrangerScrollManager.verticalOnly({super.key, this.child})
    : _mode = _ArrangerScrollManagerMode.verticalOnly;

  @override
  State<ArrangerScrollManager> createState() => _ArrangerScrollManagerState();
}

class _ArrangerScrollManagerState extends State<ArrangerScrollManager> {
  var _panYStart = double.nan;
  var _panScrollPosStart = double.nan;

  double _applyVerticalScrollDelta({
    required ArrangerViewModel viewModel,
    required double delta,
  }) {
    final previousVerticalScrollPosition = viewModel.verticalScrollPosition;

    viewModel.applyVerticalScrollDelta(delta);

    final appliedVerticalScrollDelta =
        viewModel.verticalScrollPosition - previousVerticalScrollPosition;
    final deltaScale =
        0.01 * viewModel.baseTrackHeight.clamp(minTrackHeight, maxTrackHeight);
    if (deltaScale == 0) {
      return 0;
    }

    return appliedVerticalScrollDelta / deltaScale;
  }

  void _handleVerticalPanStart({
    required ArrangerViewModel viewModel,
    required double y,
  }) {
    _panYStart = y;
    _panScrollPosStart = viewModel.verticalScrollPosition;
  }

  void _handleVerticalPanMove({
    required ArrangerViewModel viewModel,
    required double y,
  }) {
    final delta = -(y - _panYStart);
    viewModel.verticalScrollPosition = (_panScrollPosStart + delta).clamp(
      0,
      double.infinity,
    );
  }

  void _handleVerticalZoom({
    required ArrangerController controller,
    required ArrangerViewModel viewModel,
    required double pointerY,
    required double delta,
  }) {
    controller.setBaseTrackHeight(
      pointerY,
      viewModel.baseTrackHeight + delta * 15,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ArrangerController>(context, listen: false);
    final viewModel = Provider.of<ArrangerViewModel>(context);

    double onVerticalScrollChange(double delta) =>
        _applyVerticalScrollDelta(viewModel: viewModel, delta: delta);

    void onVerticalZoom(double pointerY, double delta) => _handleVerticalZoom(
      controller: controller,
      viewModel: viewModel,
      pointerY: pointerY,
      delta: delta,
    );

    if (widget._mode == _ArrangerScrollManagerMode.verticalOnly) {
      return EditorScrollManager.verticalOnly(
        onVerticalScrollChange: onVerticalScrollChange,
        onVerticalZoom: onVerticalZoom,
        child: widget.child,
      );
    }

    return EditorScrollManager.editor(
      timeRangeViewport: viewModel.timeRangeViewport,
      onVerticalScrollChange: onVerticalScrollChange,
      onVerticalPanStart: (y) {
        _handleVerticalPanStart(viewModel: viewModel, y: y);
      },
      onVerticalPanMove: (y) {
        _handleVerticalPanMove(viewModel: viewModel, y: y);
      },
      onVerticalZoom: onVerticalZoom,
      child: widget.child,
    );
  }
}

enum _ArrangerScrollManagerMode { editor, verticalOnly }
