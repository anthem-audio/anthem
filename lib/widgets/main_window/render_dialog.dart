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

import 'dart:async';
import 'dart:math';

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/render/render_range.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_tabs.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/horizontal_meter_simple.dart';
import 'package:anthem/widgets/basic/text_box.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart' hide TextBox;
import 'package:logging/logging.dart';

final _log = Logger('render_dialog');

enum _RenderRangeMode { project, loop }

class RenderDialog extends StatefulWidget {
  final ProjectId projectId;

  const RenderDialog({super.key, required this.projectId});

  @override
  State<RenderDialog> createState() => _RenderDialogState();
}

class _RenderDialogState extends State<RenderDialog> {
  static const _defaultRenderSampleRate = 48000.0;
  static const _defaultRenderBlockSize = 512;
  static const _defaultRenderOutputChannelCount = 2;

  final TextEditingController _pathController = TextEditingController();

  StreamSubscription<Response>? _renderEventSubscription;

  RenderAudioFormat _format = RenderAudioFormat.wav;
  _RenderRangeMode _rangeMode = _RenderRangeMode.project;
  bool _includeTail = true;
  bool _isRendering = false;
  double _progress = 0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();

    final project = AnthemStore.instance.projects[widget.projectId];
    if (project != null) {
      _pathController.text = _defaultOutputPath(project) ?? '';
    }
  }

  @override
  void dispose() {
    unawaited(_renderEventSubscription?.cancel());
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = AnthemStore.instance.projects[widget.projectId];
    if (project == null) {
      return SizedBox(
        width: 500,
        child: Text(
          'Project is no longer available.',
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
      );
    }

    return SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _RenderDialogRow(
            label: 'Output file',
            child: Row(
              children: [
                Expanded(
                  child: TextBox(height: 26, controller: _pathController),
                ),
                const SizedBox(width: 8),
                Button(
                  width: 72,
                  height: 26,
                  text: 'Browse...',
                  onPress: _isRendering
                      ? null
                      : () => _chooseOutputPath(project),
                ),
              ],
            ),
          ),
          _RenderDialogRow(
            label: 'Format',
            child: Align(
              alignment: Alignment.centerLeft,
              child: Dropdown(
                width: 104,
                height: 26,
                selectedID: _format.name,
                allowNoSelection: false,
                horizontalExpand: false,
                items: const [
                  DropdownItem(id: 'wav', name: 'WAV'),
                  DropdownItem(id: 'aiff', name: 'AIFF'),
                  DropdownItem(id: 'flac', name: 'FLAC'),
                  DropdownItem(id: 'oggVorbis', name: 'Ogg'),
                ],
                onChanged: _isRendering
                    ? null
                    : (id) {
                        setState(() {
                          _format = _formatFromId(id) ?? _format;
                          _pathController.text = _ensureFormatExtension(
                            _pathController.text,
                            _format,
                          );
                        });
                      },
              ),
            ),
          ),
          _RenderDialogRow(
            label: 'Range',
            child: SizedBox(
              height: 26,
              child: TextButtonTabs(
                selectedIndex: _rangeMode.index,
                tabs: [
                  (
                    label: 'Whole project',
                    onSelect: () => _setRangeMode(_RenderRangeMode.project),
                  ),
                  (
                    label: 'Loop range',
                    onSelect: () => _setRangeMode(_RenderRangeMode.loop),
                  ),
                ],
              ),
            ),
          ),
          _RenderDialogRow(
            label: 'Tail',
            child: _CheckboxRow(
              label: 'Include tail',
              value: _includeTail,
              onChanged: _isRendering
                  ? null
                  : (value) {
                      setState(() {
                        _includeTail = value;
                      });
                    },
            ),
          ),
          _RenderDialogRow(
            label: 'Progress',
            child: SizedBox(
              height: 20,
              child: HorizontalMeterSimple(
                width: 394,
                value: _progress,
                label: _progressLabel,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
                ),
              ),
              const SizedBox(width: 12),
              Opacity(
                opacity: _isRendering ? 0.6 : 1,
                child: Button(
                  width: 86,
                  height: 28,
                  text: _isRendering ? 'Rendering' : 'Render',
                  onPress: _isRendering ? null : () => _render(project),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setRangeMode(_RenderRangeMode rangeMode) {
    if (_isRendering) {
      return;
    }

    setState(() {
      _rangeMode = rangeMode;
    });
  }

  Future<void> _chooseOutputPath(ProjectModel project) async {
    final extension = _extensionForFormat(_format);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Render audio',
      fileName: _defaultFileName(project, _format),
      initialDirectory: _projectDirectory(project),
      type: FileType.custom,
      allowedExtensions: [extension],
    );

    if (path == null || !mounted) {
      return;
    }

    setState(() {
      _pathController.text = _ensureFormatExtension(path, _format);
    });
  }

  Future<void> _render(ProjectModel project) async {
    final range = _selectedRange(project);
    if (range == null) {
      setState(() {
        _statusText = _rangeMode == _RenderRangeMode.project
            ? 'No content to render.'
            : 'No valid loop range to render.';
      });
      return;
    }

    var outputPath = _ensureFormatExtension(_pathController.text, _format);
    if (outputPath.isEmpty) {
      await _chooseOutputPath(project);
      if (!mounted) {
        return;
      }

      outputPath = _ensureFormatExtension(_pathController.text, _format);
      if (outputPath.isEmpty) {
        setState(() {
          _statusText = 'Choose an output file.';
        });
        return;
      }
    }

    final renderId = getId();
    await _renderEventSubscription?.cancel();

    _renderEventSubscription = project.engine.renderEventStream.listen((event) {
      _handleRenderEvent(event, renderId);
    });

    final audioConfig = project.engine.audioConfig;

    setState(() {
      _isRendering = true;
      _progress = 0;
      _statusText = 'Preparing render...';
      _pathController.text = outputPath;
    });

    try {
      final result = await ServiceRegistry.forProject(widget.projectId)
          .projectEngineController
          .renderAudio(
            renderId: renderId,
            outputPath: outputPath,
            format: _format,
            startTick: range.startTick,
            endTick: range.endTick,
            includeTail: _includeTail,
            sampleRate: audioConfig?.sampleRate ?? _defaultRenderSampleRate,
            blockSize: audioConfig?.blockSize ?? _defaultRenderBlockSize,
            outputChannelCount:
                audioConfig?.outputChannelCount ??
                _defaultRenderOutputChannelCount,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _progress = 1;
        _statusText = 'Rendered ${result.renderedSamples} samples.';
      });
    } catch (error, stackTrace) {
      _log.warning(
        'Could not render project ${widget.projectId}.',
        error,
        stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Render failed: $error';
      });
    } finally {
      final subscription = _renderEventSubscription;
      _renderEventSubscription = null;
      await subscription?.cancel();

      if (mounted) {
        setState(() {
          _isRendering = false;
        });
      }
    }
  }

  void _handleRenderEvent(Response event, int renderId) {
    if (!mounted) {
      return;
    }

    switch (event) {
      case RenderStartedEvent e when e.renderId == renderId:
        setState(() {
          _progress = 0;
          _statusText = 'Rendering...';
        });
      case RenderProgressEvent e when e.renderId == renderId:
        setState(() {
          _progress = _sanitizeProgress(e.progress);
          _statusText =
              'Rendering ${e.renderedSamples} of ${e.totalSamples} samples...';
        });
      case RenderCompletedEvent e when e.renderId == renderId:
        setState(() {
          _progress = 1;
          _statusText = 'Rendered ${e.renderedSamples} samples.';
        });
      case RenderFailedEvent e when e.renderId == renderId:
        setState(() {
          _progress = _sanitizeProgress(
            e.totalSamples == 0 ? 0 : e.renderedSamples / e.totalSamples,
          );
          _statusText = 'Render failed: ${e.error}';
        });
      default:
        break;
    }
  }

  RenderTickRange? _selectedRange(ProjectModel project) {
    return switch (_rangeMode) {
      _RenderRangeMode.project => activeArrangementContentRenderRange(project),
      _RenderRangeMode.loop => activeArrangementLoopRenderRange(project),
    };
  }

  String get _progressLabel {
    if (_progress <= 0 && !_isRendering) {
      return '';
    }

    return '${(_progress * 100).round()}%';
  }
}

class _RenderDialogRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _RenderDialogRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(color: AnthemTheme.text.accent, fontSize: 11),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _CheckboxRow extends StatefulWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _CheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_CheckboxRow> createState() => _CheckboxRowState();
}

class _CheckboxRowState extends State<_CheckboxRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onChanged != null;

    return GestureDetector(
      onTap: isEnabled ? () => widget.onChanged?.call(!widget.value) : null,
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            _hovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _hovered = false;
          });
        },
        child: Opacity(
          opacity: isEnabled ? 1 : 0.6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.value
                      ? AnthemTheme.control.activeBackground
                      : AnthemTheme.control.background,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: _hovered
                        ? AnthemTheme.primary.main
                        : AnthemTheme.control.border,
                  ),
                ),
                child: widget.value
                    ? Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AnthemTheme.text.main,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

RenderAudioFormat? _formatFromId(String? id) {
  return switch (id) {
    'wav' => RenderAudioFormat.wav,
    'aiff' => RenderAudioFormat.aiff,
    'flac' => RenderAudioFormat.flac,
    'oggVorbis' => RenderAudioFormat.oggVorbis,
    _ => null,
  };
}

String _extensionForFormat(RenderAudioFormat format) {
  return switch (format) {
    RenderAudioFormat.wav => 'wav',
    RenderAudioFormat.aiff => 'aiff',
    RenderAudioFormat.flac => 'flac',
    RenderAudioFormat.oggVorbis => 'ogg',
  };
}

String _defaultFileName(ProjectModel project, RenderAudioFormat format) {
  return '${_sanitizeFileName(project.name)}.${_extensionForFormat(format)}';
}

String? _defaultOutputPath(ProjectModel project) {
  final directory = _projectDirectory(project);
  if (directory == null) {
    return null;
  }

  return '$directory${_pathSeparator(project.filePath!)}'
      '${_defaultFileName(project, RenderAudioFormat.wav)}';
}

String? _projectDirectory(ProjectModel project) {
  final filePath = project.filePath;
  if (filePath == null) {
    return null;
  }

  final separatorIndex = max(
    filePath.lastIndexOf('/'),
    filePath.lastIndexOf(r'\'),
  );
  if (separatorIndex < 0) {
    return null;
  }

  return filePath.substring(0, separatorIndex);
}

String _pathSeparator(String path) {
  return path.contains(r'\') ? r'\' : '/';
}

String _sanitizeFileName(String fileName) {
  final sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  return sanitized.isEmpty ? 'render' : sanitized;
}

String _ensureFormatExtension(String path, RenderAudioFormat format) {
  final trimmedPath = path.trim();
  if (trimmedPath.isEmpty) {
    return '';
  }

  final extension = _extensionForFormat(format);
  if (trimmedPath.toLowerCase().endsWith('.$extension')) {
    return trimmedPath;
  }

  final separatorIndex = max(
    trimmedPath.lastIndexOf('/'),
    trimmedPath.lastIndexOf(r'\'),
  );
  final fileNameStart = separatorIndex + 1;
  final fileName = trimmedPath.substring(fileNameStart);
  final extensionIndex = fileName.lastIndexOf('.');

  if (extensionIndex > 0) {
    return '${trimmedPath.substring(0, fileNameStart)}'
        '${fileName.substring(0, extensionIndex)}.$extension';
  }

  return '$trimmedPath.$extension';
}

double _sanitizeProgress(double progress) {
  if (!progress.isFinite) {
    return 0;
  }

  return progress.clamp(0.0, 1.0).toDouble();
}
