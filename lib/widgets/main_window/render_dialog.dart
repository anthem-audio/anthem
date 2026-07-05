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
import 'package:anthem/widgets/basic/controls/slider.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
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

        final outputSection = Row(
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
        );

        final rangeSection = SizedBox(
          height: 26,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnthemRadioButton(
                label: 'Full project',
                selected: viewModel.rangeMode == RenderDialogRangeMode.project,
                onSelected: () => widget.controller.setRangeMode(
                  RenderDialogRangeMode.project,
                ),
              ),
              const SizedBox(width: 14),
              AnthemRadioButton(
                label: 'Loop range',
                selected: viewModel.rangeMode == RenderDialogRangeMode.loop,
                disabled: !loopRangeEnabled,
                onSelected: () =>
                    widget.controller.setRangeMode(RenderDialogRangeMode.loop),
              ),
              const SizedBox(width: 14),
              Container(
                width: 1,
                height: 16,
                color: AnthemTheme.overlay.border,
              ),
              const SizedBox(width: 14),
              AnthemCheckbox(
                label: 'Include tail',
                value: viewModel.includeTail,
                onChanged: widget.controller.setIncludeTail,
              ),
            ],
          ),
        );

        final formatSection = SizedBox(
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
                onSelected: () =>
                    widget.controller.setFormat(RenderAudioFormat.oggVorbis),
              ),
              const SizedBox(width: 14),
              AnthemRadioButton(
                label: 'MP3',
                selected: viewModel.format == RenderAudioFormat.mp3,
                onSelected: () =>
                    widget.controller.setFormat(RenderAudioFormat.mp3),
              ),
            ],
          ),
        );

        final sampleRateDropdown = _DropdownOptionRow(
          title: 'Sample rate',
          selectedID: viewModel.sampleRate.toString(),
          items: widget.controller.sampleRateOptions
              .map(
                (sampleRate) => DropdownItem(
                  id: sampleRate.toString(),
                  name: '$sampleRate Hz',
                ),
              )
              .toList(),
          onChanged: (id) {
            final sampleRate = int.tryParse(id ?? '');
            if (sampleRate != null) {
              widget.controller.setSampleRate(sampleRate);
            }
          },
        );
        final mp3BitrateOptionLabels = widget.controller.mp3BitrateOptionLabels;

        final exportOptionRows = [
          if (widget.controller.showBitDepthOption)
            Row(
              children: [
                sampleRateDropdown,
                const SizedBox(width: 14),
                _DropdownOptionRow(
                  title: 'Bit depth',
                  titleWidth: 58,
                  selectedID: widget.controller.selectedBitDepth.toString(),
                  items: widget.controller.bitDepthOptions
                      .map(
                        (bitDepth) => DropdownItem(
                          id: bitDepth.toString(),
                          name: '$bitDepth-bit',
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    final bitDepth = int.tryParse(id ?? '');
                    if (bitDepth != null) {
                      widget.controller.setBitDepth(bitDepth);
                    }
                  },
                ),
              ],
            )
          else
            sampleRateDropdown,
          if (widget.controller.showWavSampleFormatOption)
            _DropdownOptionRow(
              title: 'Sample format',
              selectedID: viewModel.wavSampleFormat.name,
              items: const [
                DropdownItem(id: 'floatingPoint', name: 'Float'),
                DropdownItem(id: 'integer', name: 'Integer'),
              ],
              onChanged: (id) {
                final sampleFormat = switch (id) {
                  'floatingPoint' => RenderAudioSampleFormat.floatingPoint,
                  'integer' => RenderAudioSampleFormat.integer,
                  _ => null,
                };

                if (sampleFormat != null) {
                  widget.controller.setWavSampleFormat(sampleFormat);
                }
              },
            ),
          if (widget.controller.showFlacCompressionOption)
            _SliderOptionRow(
              title: 'Compression',
              value: viewModel.flacCompressionLevel.toDouble(),
              min: widget.controller.flacCompressionLevelMin.toDouble(),
              max: widget.controller.flacCompressionLevelMax.toDouble(),
              valueText: viewModel.flacCompressionLevel.toString(),
              onChanged: (value) =>
                  widget.controller.setFlacCompressionLevel(value.round()),
            ),
          if (widget.controller.showOggBitrateOption)
            _SliderOptionRow(
              title: 'Bitrate',
              value: viewModel.oggQualityOptionIndex.toDouble(),
              min: 0,
              max: (widget.controller.oggQualityOptionLabels.length - 1)
                  .toDouble(),
              valueText: widget
                  .controller
                  .oggQualityOptionLabels[viewModel.oggQualityOptionIndex],
              onChanged: (value) =>
                  widget.controller.setOggQualityOptionIndex(value.round()),
            ),
          if (widget.controller.showMp3BitrateOption)
            _SliderOptionRow(
              title: 'Bitrate',
              value: viewModel.mp3BitrateOptionIndex.toDouble(),
              min: 0,
              max: (mp3BitrateOptionLabels.length - 1).toDouble(),
              valueText:
                  mp3BitrateOptionLabels[viewModel.mp3BitrateOptionIndex],
              onChanged: (value) =>
                  widget.controller.setMp3BitrateOptionIndex(value.round()),
            ),
        ];

        final exportOptionsSection = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < 2; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              if (index < exportOptionRows.length)
                exportOptionRows[index]
              else
                const SizedBox(height: 24),
            ],
          ],
        );

        return SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              outputSection,
              const SizedBox(height: 12),
              rangeSection,
              const SizedBox(height: 10),
              Container(height: 1, color: AnthemTheme.overlay.border),
              const SizedBox(height: 9),
              formatSection,
              const SizedBox(height: 12),
              exportOptionsSection,
              if (viewModel.statusText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    viewModel.statusText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AnthemTheme.text.main,
                      fontSize: 11,
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

class _DropdownOptionRow extends StatelessWidget {
  final String title;
  final double titleWidth;
  final String selectedID;
  final List<DropdownItem> items;
  final void Function(String?) onChanged;

  const _DropdownOptionRow({
    required this.title,
    this.titleWidth = 82,
    required this.selectedID,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _OptionTitle(title: title, width: titleWidth),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Dropdown(
              height: 24,
              selectedID: selectedID,
              items: items,
              onChanged: onChanged,
              allowNoSelection: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderOptionRow extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String valueText;
  final void Function(double) onChanged;

  const _SliderOptionRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.valueText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _OptionTitle(title: title),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 16,
              child: Slider(
                value: value,
                min: min,
                max: max,
                axis: SliderAxis.horizontal,
                handleType: SliderHandleType.circle,
                usePointerLock: false,
                onValueChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(
              valueText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTitle extends StatelessWidget {
  final String title;
  final double width;

  const _OptionTitle({required this.title, this.width = 82});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToLastDescent: false,
        ),
        style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
      ),
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
