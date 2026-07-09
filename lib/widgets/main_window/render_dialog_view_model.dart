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
import 'package:anthem/helpers/id.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'render_dialog_view_model.g.dart';

enum RenderDialogRangeMode { project, loop }

const renderDialogDefaultSampleRate = 48000;
const renderDialogWavSampleRates = [
  8000,
  11025,
  12000,
  16000,
  22050,
  32000,
  44100,
  48000,
  88200,
  96000,
  176400,
  192000,
  352800,
  384000,
];
const renderDialogAiffSampleRates = [
  22050,
  32000,
  44100,
  48000,
  88200,
  96000,
  176400,
  192000,
];
const renderDialogOggSampleRates = [
  8000,
  11025,
  12000,
  16000,
  22050,
  32000,
  44100,
  48000,
  88200,
  96000,
  176400,
  192000,
];
const renderDialogMp3SampleRates = [32000, 44100, 48000];
const renderDialogWavBitDepths = [8, 16, 24, 32];
const renderDialogAiffBitDepths = [8, 16, 24];
const renderDialogFlacBitDepths = [16, 24];
const renderDialogFlacCompressionLevelMin = 0;
const renderDialogFlacCompressionLevelMax = 8;
const renderDialogOggQualityOptionIndexMin = 0;
const renderDialogOggQualityOptionIndexMax = 10;
const renderDialogMp3BitrateOptionIndexMin = 0;
const renderDialogMp3BitrateOptionIndexMax = 13;

const _sampleRateKey = 'render.sampleRate';
const _wavBitDepthKey = 'render.wavBitDepth';
const _wavSampleFormatKey = 'render.wavSampleFormat';
const _aiffBitDepthKey = 'render.aiffBitDepth';
const _flacBitDepthKey = 'render.flacBitDepth';
const _flacCompressionLevelKey = 'render.flacCompressionLevel';
const _oggQualityOptionIndexKey = 'render.oggQualityOptionIndex';
const _mp3BitrateOptionIndexKey = 'render.mp3BitrateOptionIndex';
const _rangeModeKey = 'render.rangeMode';
const _includeTailKey = 'render.includeTail';
const _renderDialogPreferenceKeys = {
  _sampleRateKey,
  _wavBitDepthKey,
  _wavSampleFormatKey,
  _aiffBitDepthKey,
  _flacBitDepthKey,
  _flacCompressionLevelKey,
  _oggQualityOptionIndexKey,
  _mp3BitrateOptionIndexKey,
  _rangeModeKey,
  _includeTailKey,
};

// ignore: library_private_types_in_public_api
class RenderDialogViewModel = _RenderDialogViewModel
    with _$RenderDialogViewModel;

abstract class _RenderDialogViewModel with Store {
  final ProjectId projectId;

  @observable
  String filePath;

  @observable
  RenderAudioFormat format;

  @observable
  int sampleRate;

  @observable
  int wavBitDepth = 32;

  @observable
  RenderAudioSampleFormat wavSampleFormat =
      RenderAudioSampleFormat.floatingPoint;

  @observable
  int aiffBitDepth = 24;

  @observable
  int flacBitDepth = 24;

  @observable
  int flacCompressionLevel = 5;

  @observable
  int oggQualityOptionIndex = 9;

  @observable
  int mp3BitrateOptionIndex = 13;

  @observable
  RenderDialogRangeMode rangeMode = RenderDialogRangeMode.project;

  @observable
  bool includeTail = true;

  @observable
  String statusText = '';

  _RenderDialogViewModel({
    required this.projectId,
    required this.filePath,
    required this.format,
    required this.sampleRate,
  });

  bool get hasFilePath => filePath.trim().isNotEmpty;

  Future<void> loadPreferences(SharedPreferencesAsync preferences) async {
    final values = await preferences.getAll(
      allowList: _renderDialogPreferenceKeys,
    );

    sampleRate =
        _readInt(values, _sampleRateKey, _isValidSampleRate) ?? sampleRate;
    wavBitDepth =
        _readInt(values, _wavBitDepthKey, renderDialogWavBitDepths.contains) ??
        wavBitDepth;

    final savedWavSampleFormat = _enumValueByName(
      RenderAudioSampleFormat.values,
      _readString(values, _wavSampleFormatKey),
    );
    if (savedWavSampleFormat != null) {
      wavSampleFormat = savedWavSampleFormat;
    }

    aiffBitDepth =
        _readInt(
          values,
          _aiffBitDepthKey,
          renderDialogAiffBitDepths.contains,
        ) ??
        aiffBitDepth;
    flacBitDepth =
        _readInt(
          values,
          _flacBitDepthKey,
          renderDialogFlacBitDepths.contains,
        ) ??
        flacBitDepth;
    flacCompressionLevel =
        _readInt(
          values,
          _flacCompressionLevelKey,
          _isValidFlacCompressionLevel,
        ) ??
        flacCompressionLevel;
    oggQualityOptionIndex =
        _readInt(
          values,
          _oggQualityOptionIndexKey,
          _isValidOggQualityOptionIndex,
        ) ??
        oggQualityOptionIndex;
    mp3BitrateOptionIndex =
        _readInt(
          values,
          _mp3BitrateOptionIndexKey,
          _isValidMp3BitrateOptionIndex,
        ) ??
        mp3BitrateOptionIndex;

    final savedRangeMode = _enumValueByName(
      RenderDialogRangeMode.values,
      _readString(values, _rangeModeKey),
    );
    if (savedRangeMode != null) {
      rangeMode = savedRangeMode;
    }

    includeTail = _readBool(values, _includeTailKey) ?? includeTail;
  }

  Future<void> savePreferences(SharedPreferencesAsync preferences) async {
    await Future.wait([
      preferences.setInt(_sampleRateKey, sampleRate),
      preferences.setInt(_wavBitDepthKey, wavBitDepth),
      preferences.setString(_wavSampleFormatKey, wavSampleFormat.name),
      preferences.setInt(_aiffBitDepthKey, aiffBitDepth),
      preferences.setInt(_flacBitDepthKey, flacBitDepth),
      preferences.setInt(_flacCompressionLevelKey, flacCompressionLevel),
      preferences.setInt(_oggQualityOptionIndexKey, oggQualityOptionIndex),
      preferences.setInt(_mp3BitrateOptionIndexKey, mp3BitrateOptionIndex),
      preferences.setString(_rangeModeKey, rangeMode.name),
      preferences.setBool(_includeTailKey, includeTail),
    ]);
  }
}

bool _isValidSampleRate(int value) {
  return renderDialogWavSampleRates.contains(value) ||
      renderDialogAiffSampleRates.contains(value) ||
      renderDialogOggSampleRates.contains(value) ||
      renderDialogMp3SampleRates.contains(value);
}

bool _isValidFlacCompressionLevel(int value) {
  return value >= renderDialogFlacCompressionLevelMin &&
      value <= renderDialogFlacCompressionLevelMax;
}

bool _isValidOggQualityOptionIndex(int value) {
  return value >= renderDialogOggQualityOptionIndexMin &&
      value <= renderDialogOggQualityOptionIndexMax;
}

bool _isValidMp3BitrateOptionIndex(int value) {
  return value >= renderDialogMp3BitrateOptionIndexMin &&
      value <= renderDialogMp3BitrateOptionIndexMax;
}

bool? _readBool(Map<String, Object?> values, String key) {
  try {
    return values[key] as bool?;
  } on TypeError {
    return null;
  }
}

int? _readInt(
  Map<String, Object?> values,
  String key,
  bool Function(int) isValid,
) {
  try {
    final value = values[key] as int?;
    if (value == null || !isValid(value)) {
      return null;
    }

    return value;
  } on TypeError {
    return null;
  }
}

String? _readString(Map<String, Object?> values, String key) {
  try {
    return values[key] as String?;
  } on TypeError {
    return null;
  }
}

T? _enumValueByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) {
    return null;
  }

  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  return null;
}
