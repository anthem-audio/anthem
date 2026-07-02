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

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/logic/render/render_range.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/checkbox.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/radio_button.dart';
import 'package:anthem/widgets/main_window/render_dialog_controller.dart';
import 'package:anthem/widgets/main_window/render_dialog_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

class RenderDialog extends StatefulWidget {
  final RenderDialogController controller;

  const RenderDialog({super.key, required this.controller});

  @override
  State<RenderDialog> createState() => _RenderDialogState();
}

class _RenderDialogState extends State<RenderDialog> {
  late ReactionDisposer _loopRangeDisposer;

  @override
  void initState() {
    super.initState();
    _loopRangeDisposer = _createLoopRangeDisposer();
  }

  @override
  void didUpdateWidget(covariant RenderDialog oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _loopRangeDisposer();
      _loopRangeDisposer = _createLoopRangeDisposer();
    }
  }

  @override
  void dispose() {
    _loopRangeDisposer();
    super.dispose();
  }

  ReactionDisposer _createLoopRangeDisposer() {
    return reaction<bool>((_) => _activeArrangementHasLoopRange(), (
      hasLoopRange,
    ) {
      final viewModel = widget.controller.viewModel;
      if (!hasLoopRange && viewModel.rangeMode == RenderDialogRangeMode.loop) {
        widget.controller.setRangeMode(RenderDialogRangeMode.project);
      }
    }, fireImmediately: true);
  }

  bool _activeArrangementHasLoopRange() {
    final project =
        AnthemStore.instance.projects[widget.controller.viewModel.projectId];

    if (project == null) {
      return false;
    }

    return activeArrangementLoopRenderRange(project) != null;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final viewModel = widget.controller.viewModel;
        final project = AnthemStore.instance.projects[viewModel.projectId];
        if (project == null) {
          return SizedBox(
            width: 500,
            child: Text(
              'Project is no longer available.',
              style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
            ),
          );
        }

        final loopRangeEnabled =
            activeArrangementLoopRenderRange(project) != null;

        return SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                children: [
                  Button(
                    width: 24,
                    height: 24,
                    contentPadding: const EdgeInsets.all(4),
                    icon: Icons.folder,
                    onPress: widget.controller.chooseFile,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _OutputPathDisplay(path: viewModel.filePath)),
                ],
              ),
              SizedBox(
                height: 26,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnthemRadioButton(
                      label: 'WAV',
                      selected: viewModel.format == RenderAudioFormat.wav,
                      onSelected: () =>
                          widget.controller.setFormat(RenderAudioFormat.wav),
                    ),
                    const SizedBox(width: 14),
                    AnthemRadioButton(
                      label: 'AIFF',
                      selected: viewModel.format == RenderAudioFormat.aiff,
                      onSelected: () =>
                          widget.controller.setFormat(RenderAudioFormat.aiff),
                    ),
                    const SizedBox(width: 14),
                    AnthemRadioButton(
                      label: 'FLAC',
                      selected: viewModel.format == RenderAudioFormat.flac,
                      onSelected: () =>
                          widget.controller.setFormat(RenderAudioFormat.flac),
                    ),
                    const SizedBox(width: 14),
                    AnthemRadioButton(
                      label: 'Ogg',
                      selected: viewModel.format == RenderAudioFormat.oggVorbis,
                      onSelected: () => widget.controller.setFormat(
                        RenderAudioFormat.oggVorbis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 26,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnthemRadioButton(
                      label: 'Full project',
                      selected:
                          viewModel.rangeMode == RenderDialogRangeMode.project,
                      onSelected: () => widget.controller.setRangeMode(
                        RenderDialogRangeMode.project,
                      ),
                    ),
                    const SizedBox(width: 14),
                    AnthemRadioButton(
                      label: 'Loop range',
                      selected:
                          viewModel.rangeMode == RenderDialogRangeMode.loop,
                      disabled: !loopRangeEnabled,
                      onSelected: () => widget.controller.setRangeMode(
                        RenderDialogRangeMode.loop,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 1,
                      height: 16,
                      color: AnthemTheme.panel.border,
                    ),
                    const SizedBox(width: 14),
                    AnthemCheckbox(
                      label: 'Include tail',
                      value: viewModel.includeTail,
                      onChanged: widget.controller.setIncludeTail,
                    ),
                  ],
                ),
              ),
              if (viewModel.statusText.isNotEmpty)
                Text(
                  viewModel.statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OutputPathDisplay extends StatelessWidget {
  final String path;

  const _OutputPathDisplay({required this.path});

  @override
  Widget build(BuildContext context) {
    final hasPath = path.isNotEmpty;
    final style = TextStyle(
      color: hasPath ? AnthemTheme.text.main : AnthemTheme.text.disabled,
      fontSize: 11,
    );

    return SizedBox(
      height: 26,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          hasPath ? path : 'Choose a file',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}
