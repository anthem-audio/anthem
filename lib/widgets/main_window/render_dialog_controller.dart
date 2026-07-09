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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/file_exists.dart';
import 'package:anthem/logic/render/project_render_controller.dart';
import 'package:anthem/logic/render/render_range.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/main_window/render_dialog_view_model.dart';
import 'package:anthem/widgets/main_window/render_progress_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('render_dialog_controller');

const _renderAudioFormatExtensions = ['wav', 'aiff', 'flac', 'ogg', 'mp3'];
const _oggQualityOptionLabels = [
  '64 kbps',
  '80 kbps',
  '96 kbps',
  '112 kbps',
  '128 kbps',
  '160 kbps',
  '192 kbps',
  '224 kbps',
  '256 kbps',
  '320 kbps',
  '500 kbps',
];
const _mp3BitrateOptionIndexOffset = 10;
const _mp3BitrateOptionLabels = [
  '32 kbps',
  '40 kbps',
  '48 kbps',
  '56 kbps',
  '64 kbps',
  '80 kbps',
  '96 kbps',
  '112 kbps',
  '128 kbps',
  '160 kbps',
  '192 kbps',
  '224 kbps',
  '256 kbps',
  '320 kbps',
];

class RenderDialogController {
  final RenderDialogViewModel viewModel;
  final SharedPreferencesAsync preferences;

  RenderDialogController({
    required this.viewModel,
    SharedPreferencesAsync? preferences,
  }) : preferences = preferences ?? ServiceRegistry.preferences;

  List<int> get sampleRateOptions => _sampleRatesForFormat(viewModel.format);

  List<int> get bitDepthOptions => _bitDepthsForFormat(viewModel.format);

  int get selectedBitDepth => _activeBitDepth;

  bool get showBitDepthOption => bitDepthOptions.isNotEmpty;

  bool get showWavSampleFormatOption =>
      viewModel.format == RenderAudioFormat.wav && viewModel.wavBitDepth == 32;

  bool get showFlacCompressionOption =>
      viewModel.format == RenderAudioFormat.flac;

  bool get showOggBitrateOption =>
      viewModel.format == RenderAudioFormat.oggVorbis;

  bool get showMp3BitrateOption => viewModel.format == RenderAudioFormat.mp3;

  List<String> get oggQualityOptionLabels => _oggQualityOptionLabels;

  List<String> get mp3BitrateOptionLabels => _mp3BitrateOptionLabels;

  int get flacCompressionLevelMin => renderDialogFlacCompressionLevelMin;

  int get flacCompressionLevelMax => renderDialogFlacCompressionLevelMax;

  bool get outputWillOverwrite {
    final outputPath = viewModel.filePath.trim();
    return outputPath.isNotEmpty && fileExists(outputPath);
  }

  factory RenderDialogController.forProject(ProjectModel project) {
    const format = RenderAudioFormat.wav;

    return RenderDialogController(
      viewModel: RenderDialogViewModel(
        projectId: project.id,
        filePath: _defaultRenderFilePath(project, format: format),
        format: format,
        sampleRate: _defaultSampleRateForProject(project, format),
      ),
    );
  }

  void setFilePath(String value) {
    final pathFormat = _renderAudioFormatForPath(value);

    if (pathFormat != null) {
      _setFormat(pathFormat);
      viewModel.filePath = value.trim();
      return;
    }

    viewModel.filePath = _normalizeRenderFilePath(value, viewModel.format);
  }

  void setFormat(RenderAudioFormat value) {
    _setFormat(value);

    if (viewModel.hasFilePath) {
      viewModel.filePath = _withRenderAudioExtension(viewModel.filePath, value);
    }
  }

  void setSampleRate(int value) {
    viewModel.sampleRate = _coerceSampleRateForFormat(value, viewModel.format);
  }

  void setBitDepth(int value) {
    switch (viewModel.format) {
      case RenderAudioFormat.wav:
        if (renderDialogWavBitDepths.contains(value)) {
          viewModel.wavBitDepth = value;
        }
      case RenderAudioFormat.aiff:
        if (renderDialogAiffBitDepths.contains(value)) {
          viewModel.aiffBitDepth = value;
        }
      case RenderAudioFormat.flac:
        if (renderDialogFlacBitDepths.contains(value)) {
          viewModel.flacBitDepth = value;
        }
      case RenderAudioFormat.oggVorbis:
        break;
      case RenderAudioFormat.mp3:
        break;
    }
  }

  void setWavSampleFormat(RenderAudioSampleFormat value) {
    viewModel.wavSampleFormat = value;
  }

  void setFlacCompressionLevel(int value) {
    viewModel.flacCompressionLevel = value.clamp(
      renderDialogFlacCompressionLevelMin,
      renderDialogFlacCompressionLevelMax,
    );
  }

  void setOggQualityOptionIndex(int value) {
    viewModel.oggQualityOptionIndex = value.clamp(
      renderDialogOggQualityOptionIndexMin,
      renderDialogOggQualityOptionIndexMax,
    );
  }

  void setMp3BitrateOptionIndex(int value) {
    viewModel.mp3BitrateOptionIndex = value.clamp(
      renderDialogMp3BitrateOptionIndexMin,
      renderDialogMp3BitrateOptionIndexMax,
    );
  }

  void setRangeMode(RenderDialogRangeMode value) {
    viewModel.rangeMode = value;
  }

  void setIncludeTail(bool value) {
    viewModel.includeTail = value;
  }

  Future<void> loadSavedState() async {
    try {
      await viewModel.loadPreferences(preferences);
    } catch (error, stackTrace) {
      _log.warning(
        'Could not load saved render dialog state.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> saveState() async {
    try {
      await viewModel.savePreferences(preferences);
    } catch (error, stackTrace) {
      _log.warning('Could not save render dialog state.', error, stackTrace);
    }
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
    final request = await createRenderRequest();
    if (request == null) {
      return;
    }

    final project = AnthemStore.instance.projects[viewModel.projectId];
    if (project == null) {
      _setStatusText('Project is no longer available.');
      return;
    }

    if (project.engineState != EngineState.running) {
      _setStatusText('Engine is not running.');
      return;
    }

    unawaited(saveState());

    final task = ServiceRegistry.forProject(
      viewModel.projectId,
    ).projectRenderController.startRender(request);

    final dialogController = ServiceRegistry.dialogController;
    dialogController.closeDialog();
    dialogController.showDialog(
      title: 'Rendering',
      content: RenderProgressDialog(task: task),
      dismissible: false,
    );
  }

  Future<ProjectRenderRequest?> createRenderRequest() async {
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

    return ProjectRenderRequest(
      outputPath: viewModel.filePath.trim(),
      format: viewModel.format,
      range: range,
      includeTail: viewModel.includeTail,
      sampleRate: viewModel.sampleRate,
      bitDepth: _activeBitDepth,
      qualityOptionIndex: _activeQualityOptionIndex,
      sampleFormat: _activeSampleFormat,
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

  int get _activeBitDepth {
    return switch (viewModel.format) {
      RenderAudioFormat.wav => viewModel.wavBitDepth,
      RenderAudioFormat.aiff => viewModel.aiffBitDepth,
      RenderAudioFormat.flac => viewModel.flacBitDepth,
      RenderAudioFormat.oggVorbis => 32,
      RenderAudioFormat.mp3 => 16,
    };
  }

  int get _activeQualityOptionIndex {
    return switch (viewModel.format) {
      RenderAudioFormat.flac => viewModel.flacCompressionLevel,
      RenderAudioFormat.oggVorbis => viewModel.oggQualityOptionIndex,
      RenderAudioFormat.mp3 =>
        viewModel.mp3BitrateOptionIndex + _mp3BitrateOptionIndexOffset,
      RenderAudioFormat.wav || RenderAudioFormat.aiff => 0,
    };
  }

  RenderAudioSampleFormat get _activeSampleFormat {
    return viewModel.format == RenderAudioFormat.wav
        ? viewModel.wavSampleFormat
        : RenderAudioSampleFormat.floatingPoint;
  }

  void _setFormat(RenderAudioFormat value) {
    viewModel.format = value;
    viewModel.sampleRate = _coerceSampleRateForFormat(
      viewModel.sampleRate,
      value,
    );
  }
}

int _defaultSampleRateForProject(
  ProjectModel project,
  RenderAudioFormat format,
) {
  final projectSampleRate =
      project.engine.audioConfig?.sampleRate.round() ??
      renderDialogDefaultSampleRate;

  return _coerceSampleRateForFormat(projectSampleRate, format);
}

List<int> _sampleRatesForFormat(RenderAudioFormat format) {
  return switch (format) {
    RenderAudioFormat.wav => renderDialogWavSampleRates,
    RenderAudioFormat.aiff => renderDialogAiffSampleRates,
    RenderAudioFormat.flac => renderDialogWavSampleRates,
    RenderAudioFormat.oggVorbis => renderDialogOggSampleRates,
    RenderAudioFormat.mp3 => renderDialogMp3SampleRates,
  };
}

List<int> _bitDepthsForFormat(RenderAudioFormat format) {
  return switch (format) {
    RenderAudioFormat.wav => renderDialogWavBitDepths,
    RenderAudioFormat.aiff => renderDialogAiffBitDepths,
    RenderAudioFormat.flac => renderDialogFlacBitDepths,
    RenderAudioFormat.oggVorbis => const [],
    RenderAudioFormat.mp3 => const [],
  };
}

int _coerceSampleRateForFormat(int sampleRate, RenderAudioFormat format) {
  final sampleRates = _sampleRatesForFormat(format);

  if (sampleRates.contains(sampleRate)) {
    return sampleRate;
  }

  return sampleRates.reduce((nearest, candidate) {
    final nearestDistance = (nearest - sampleRate).abs();
    final candidateDistance = (candidate - sampleRate).abs();

    if (candidateDistance < nearestDistance) {
      return candidate;
    }

    return nearest;
  });
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
    'mp3' => RenderAudioFormat.mp3,
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
    RenderAudioFormat.mp3 => 'mp3',
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
