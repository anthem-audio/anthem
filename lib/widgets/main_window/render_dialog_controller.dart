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

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/render/render_range.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/horizontal_meter_simple.dart';
import 'package:anthem/widgets/main_window/render_dialog_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _log = Logger('render_dialog_controller');

const _renderAudioFormatExtensions = ['wav', 'aiff', 'flac', 'ogg'];

class RenderDialogController {
  final RenderDialogViewModel viewModel;

  RenderDialogController({required this.viewModel});

  factory RenderDialogController.forProject(ProjectModel project) {
    const format = RenderAudioFormat.wav;

    return RenderDialogController(
      viewModel: RenderDialogViewModel(
        projectId: project.id,
        filePath: _defaultRenderFilePath(project, format: format),
        format: format,
      ),
    );
  }

  void setFilePath(String value) {
    final pathFormat = _renderAudioFormatForPath(value);

    if (pathFormat != null) {
      viewModel.format = pathFormat;
      viewModel.filePath = value.trim();
      return;
    }

    viewModel.filePath = _normalizeRenderFilePath(value, viewModel.format);
  }

  void setFormat(RenderAudioFormat value) {
    viewModel.format = value;

    if (viewModel.hasFilePath) {
      viewModel.filePath = _withRenderAudioExtension(viewModel.filePath, value);
    }
  }

  void setRangeMode(RenderDialogRangeMode value) {
    viewModel.rangeMode = value;
  }

  void setIncludeTail(bool value) {
    viewModel.includeTail = value;
  }

  Future<bool> chooseFile() async {
    final project = AnthemStore.instance.projects[viewModel.projectId];
    final fileName = viewModel.hasFilePath
        ? _fileNameForPath(viewModel.filePath)
        : _defaultFileName(project);
    final initialDirectory = viewModel.hasFilePath
        ? _directoryForPath(viewModel.filePath) ?? _projectDirectory(project)
        : _projectDirectory(project);

    final path = await FilePicker.saveFile(
      dialogTitle: 'Render audio',
      fileName: fileName,
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: _renderAudioFormatExtensions,
    );

    if (path == null) {
      return false;
    }

    setFilePath(path);
    _clearStatusText();
    return true;
  }

  Future<void> render() async {
    final renderConfig = await _createRenderConfig();
    if (renderConfig == null) {
      return;
    }

    final dialogController = ServiceRegistry.dialogController;
    dialogController.closeDialog();
    dialogController.showDialog(
      title: 'Rendering',
      content: _RenderProgressDialog(config: renderConfig),
      dismissible: false,
    );
  }

  Future<_RenderConfig?> _createRenderConfig() async {
    final project = AnthemStore.instance.projects[viewModel.projectId];
    if (project == null) {
      _setStatusText('Project is no longer available.');
      return null;
    }

    final range = _selectedRange(project);
    if (range == null) {
      _setStatusText(
        viewModel.rangeMode == RenderDialogRangeMode.project
            ? 'No content to render.'
            : 'No valid loop range to render.',
      );
      return null;
    }

    if (!viewModel.hasFilePath) {
      final pickedFile = await chooseFile();
      if (!pickedFile) {
        _setStatusText('Choose an output file.');
        return null;
      }
    }

    _clearStatusText();

    return _RenderConfig(
      projectId: viewModel.projectId,
      outputPath: viewModel.filePath.trim(),
      format: viewModel.format,
      range: range,
      includeTail: viewModel.includeTail,
    );
  }

  RenderTickRange? _selectedRange(ProjectModel project) {
    return switch (viewModel.rangeMode) {
      RenderDialogRangeMode.project => activeArrangementContentRenderRange(
        project,
      ),
      RenderDialogRangeMode.loop => activeArrangementLoopRenderRange(project),
    };
  }

  String _defaultFileName(ProjectModel? project) {
    if (project == null) {
      return 'render.${_extensionForRenderAudioFormat(viewModel.format)}';
    }

    return '${_defaultRenderFileNameStem(project)}.${_extensionForRenderAudioFormat(viewModel.format)}';
  }

  String? _projectDirectory(ProjectModel? project) {
    if (project == null) {
      return null;
    }

    final filePath = project.filePath;
    if (filePath == null) {
      return null;
    }

    return _directoryForPath(filePath);
  }

  void _setStatusText(String value) {
    viewModel.statusText = value;
  }

  void _clearStatusText() {
    viewModel.statusText = '';
  }
}

class _RenderConfig {
  final ProjectId projectId;
  final String outputPath;
  final RenderAudioFormat format;
  final RenderTickRange range;
  final bool includeTail;

  const _RenderConfig({
    required this.projectId,
    required this.outputPath,
    required this.format,
    required this.range,
    required this.includeTail,
  });
}

class _RenderProgressDialog extends StatefulWidget {
  final _RenderConfig config;

  const _RenderProgressDialog({required this.config});

  @override
  State<_RenderProgressDialog> createState() => _RenderProgressDialogState();
}

class _RenderProgressDialogState extends State<_RenderProgressDialog> {
  static const _defaultRenderSampleRate = 48000.0;
  static const _defaultRenderBlockSize = 512;
  static const _defaultRenderOutputChannelCount = 2;

  StreamSubscription<Response>? _renderEventSubscription;
  double _progress = 0;
  String _statusText = 'Preparing render...';

  @override
  void initState() {
    super.initState();
    unawaited(_render());
  }

  @override
  void dispose() {
    unawaited(_renderEventSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          SizedBox(
            height: 24,
            child: HorizontalMeterSimple(
              width: 500,
              value: _progress,
              label: _progressLabel,
            ),
          ),
          Text(
            _statusText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _render() async {
    final project = AnthemStore.instance.projects[widget.config.projectId];
    if (project == null) {
      _showRenderFailedDialog('Project is no longer available.');
      return;
    }

    final renderId = getId();
    await _renderEventSubscription?.cancel();

    _renderEventSubscription = project.engine.renderEventStream.listen((event) {
      _handleRenderEvent(event, renderId);
    });

    final audioConfig = project.engine.audioConfig;

    setState(() {
      _progress = 0;
      _statusText = 'Preparing render...';
    });

    try {
      final result = await ServiceRegistry.forProject(widget.config.projectId)
          .projectEngineController
          .renderAudio(
            renderId: renderId,
            outputPath: widget.config.outputPath,
            format: widget.config.format,
            startTick: widget.config.range.startTick,
            endTick: widget.config.range.endTick,
            includeTail: widget.config.includeTail,
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

      ServiceRegistry.dialogController.closeDialog();
    } catch (error, stackTrace) {
      _log.warning(
        'Could not render project ${widget.config.projectId}.',
        error,
        stackTrace,
      );

      if (!mounted) {
        return;
      }

      _showRenderFailedDialog('Render failed: $error');
    } finally {
      final subscription = _renderEventSubscription;
      _renderEventSubscription = null;
      await subscription?.cancel();
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
          _statusText = e.totalSamples > 0
              ? 'Rendering 0 of ${e.totalSamples} samples...'
              : 'Rendering...';
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

  void _showRenderFailedDialog(String message) {
    final dialogController = ServiceRegistry.dialogController;
    dialogController.closeDialog();
    dialogController.showDialog(
      title: 'Render Failed',
      content: SizedBox(
        width: 500,
        child: Text(
          message,
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
      ),
      buttons: [DialogButton.ok()],
    );
  }

  String get _progressLabel {
    if (_progress <= 0) {
      return '';
    }

    return '${(_progress * 100).round()}%';
  }
}

double _sanitizeProgress(double progress) {
  if (!progress.isFinite) {
    return 0;
  }

  return progress.clamp(0.0, 1.0).toDouble();
}

String _defaultRenderFilePath(
  ProjectModel project, {
  RenderAudioFormat format = RenderAudioFormat.wav,
}) {
  return _joinPath(
    _projectDirectoryForPath(project.filePath),
    '${_defaultRenderFileNameStem(project)}.${_extensionForRenderAudioFormat(format)}',
  );
}

String _defaultRenderFileNameStem(ProjectModel project) {
  final fileNameStem = _fileNameStemForInput(project.name);
  return fileNameStem.isEmpty ? 'render' : fileNameStem;
}

String? _projectDirectoryForPath(String? filePath) {
  if (filePath == null) {
    return null;
  }

  return _directoryForPath(filePath);
}

String? _directoryForPath(String filePath) {
  final directory = path.dirname(filePath);
  if (directory == '.') {
    return null;
  }

  return directory;
}

String _fileNameForPath(String filePath) {
  return path.basename(filePath);
}

String _normalizeRenderFilePath(
  String filePath,
  RenderAudioFormat fallbackFormat,
) {
  final trimmedPath = filePath.trim();
  if (trimmedPath.isEmpty) {
    return '';
  }

  if (_renderAudioFormatForPath(trimmedPath) != null) {
    return trimmedPath;
  }

  return _withRenderAudioExtension(trimmedPath, fallbackFormat);
}

String _withRenderAudioExtension(String filePath, RenderAudioFormat format) {
  final trimmedPath = filePath.trim();
  if (trimmedPath.isEmpty) {
    return '';
  }

  return path.setExtension(
    trimmedPath,
    '.${_extensionForRenderAudioFormat(format)}',
  );
}

RenderAudioFormat? _renderAudioFormatForPath(String filePath) {
  final extension = _extensionForPath(filePath);

  return switch (extension) {
    'wav' => RenderAudioFormat.wav,
    'aiff' => RenderAudioFormat.aiff,
    'aif' => RenderAudioFormat.aiff,
    'flac' => RenderAudioFormat.flac,
    'ogg' => RenderAudioFormat.oggVorbis,
    _ => null,
  };
}

String? _extensionForPath(String filePath) {
  final extension = path.extension(filePath);
  if (extension.isEmpty || extension == '.') {
    return null;
  }

  return extension.substring(1).toLowerCase();
}

String _extensionForRenderAudioFormat(RenderAudioFormat format) {
  return switch (format) {
    RenderAudioFormat.wav => 'wav',
    RenderAudioFormat.aiff => 'aiff',
    RenderAudioFormat.flac => 'flac',
    RenderAudioFormat.oggVorbis => 'ogg',
  };
}

String _fileNameStemForInput(String fileName) {
  final sanitized = _sanitizeFileNameStem(fileName);
  if (sanitized.isEmpty) {
    return '';
  }

  return _stripSupportedAudioExtension(sanitized);
}

String _sanitizeFileNameStem(String fileName, {String fallback = ''}) {
  final sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  return sanitized.isEmpty ? fallback : sanitized;
}

String _stripSupportedAudioExtension(String fileName) {
  for (final format in RenderAudioFormat.values) {
    final extension = _extensionForRenderAudioFormat(format);
    final suffix = '.$extension';

    if (!fileName.toLowerCase().endsWith(suffix)) {
      continue;
    }

    final extensionStart = fileName.length - suffix.length;
    if (extensionStart > 0) {
      return fileName.substring(0, extensionStart);
    }
  }

  return fileName;
}

String _joinPath(String? directory, String fileName) {
  final trimmedDirectory = directory?.trim();
  if (trimmedDirectory == null || trimmedDirectory.isEmpty) {
    return fileName;
  }

  return path.join(trimmedDirectory, fileName);
}
