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

import 'dart:io';

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/widgets/main_window/render_dialog_controller.dart';
import 'package:anthem/widgets/main_window/render_dialog_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test('setFilePath adds the fallback format extension', () {
    final controller = _createController(filePath: '');

    controller.setFilePath(r'C:\renders\mix');

    expect(controller.viewModel.filePath, equals(r'C:\renders\mix.wav'));
    expect(controller.viewModel.format, equals(RenderAudioFormat.wav));
  });

  test('setFilePath updates format from supported extension', () {
    final controller = _createController(filePath: r'C:\renders\mix.wav');

    controller.setFilePath(r'C:\renders\mix.mp3');

    expect(controller.viewModel.filePath, equals(r'C:\renders\mix.mp3'));
    expect(controller.viewModel.format, equals(RenderAudioFormat.mp3));
  });

  test('setFilePath adds the current format extension when missing', () {
    final controller = _createController(
      filePath: r'C:\renders\mix.flac',
      format: RenderAudioFormat.flac,
    );

    controller.setFilePath(r'C:\renders\alternate');

    expect(controller.viewModel.filePath, equals(r'C:\renders\alternate.flac'));
    expect(controller.viewModel.format, equals(RenderAudioFormat.flac));
  });

  test('setFormat replaces the path extension', () {
    final controller = _createController(filePath: r'C:\renders\mix.wav');

    controller.setFormat(RenderAudioFormat.oggVorbis);

    expect(controller.viewModel.filePath, equals(r'C:\renders\mix.ogg'));
    expect(controller.viewModel.format, equals(RenderAudioFormat.oggVorbis));
  });

  test('outputWillOverwrite reflects the current file path', () {
    final tempDirectory = Directory.systemTemp.createTempSync(
      'anthem_render_dialog_controller_test_',
    );

    try {
      final filePath = path.join(tempDirectory.path, 'mix.wav');
      final alternateFilePath = path.join(tempDirectory.path, 'alternate.wav');
      File(filePath).writeAsStringSync('');

      final controller = _createController(filePath: filePath);

      expect(controller.outputWillOverwrite, isTrue);

      controller.setFilePath(alternateFilePath);

      expect(controller.outputWillOverwrite, isFalse);
    } finally {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('outputWillOverwrite updates when format changes the file path', () {
    final tempDirectory = Directory.systemTemp.createTempSync(
      'anthem_render_dialog_controller_test_',
    );

    try {
      final wavPath = path.join(tempDirectory.path, 'mix.wav');
      final mp3Path = path.join(tempDirectory.path, 'mix.mp3');
      File(mp3Path).writeAsStringSync('');

      final controller = _createController(filePath: wavPath);

      expect(controller.outputWillOverwrite, isFalse);

      controller.setFormat(RenderAudioFormat.mp3);

      expect(controller.viewModel.filePath, equals(mp3Path));
      expect(controller.outputWillOverwrite, isTrue);
    } finally {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('setFormat coerces sample rate to the selected format', () {
    final controller = _createController(
      filePath: r'C:\renders\mix.wav',
      sampleRate: 384000,
    );

    controller.setFormat(RenderAudioFormat.oggVorbis);

    expect(controller.viewModel.sampleRate, equals(192000));
  });

  test(
    'format-specific export options are preserved when switching formats',
    () {
      final controller = _createController(filePath: r'C:\renders\mix.wav');

      controller.setBitDepth(16);
      controller.setFormat(RenderAudioFormat.flac);
      controller.setBitDepth(24);
      controller.setFlacCompressionLevel(8);
      controller.setFormat(RenderAudioFormat.mp3);
      controller.setMp3BitrateOptionIndex(6);
      controller.setFormat(RenderAudioFormat.wav);

      expect(controller.viewModel.wavBitDepth, equals(16));
      expect(controller.viewModel.flacBitDepth, equals(24));
      expect(controller.viewModel.flacCompressionLevel, equals(8));
      expect(controller.viewModel.mp3BitrateOptionIndex, equals(6));
    },
  );

  test('MP3 bitrate slider uses constant bitrate labels', () {
    final controller = _createController(
      filePath: r'C:\renders\mix.mp3',
      format: RenderAudioFormat.mp3,
    );

    expect(controller.mp3BitrateOptionLabels.first, equals('32 kbps'));
    expect(controller.mp3BitrateOptionLabels[6], equals('96 kbps'));
    expect(controller.mp3BitrateOptionLabels.last, equals('320 kbps'));
    expect(controller.viewModel.mp3BitrateOptionIndex, equals(13));

    controller.setMp3BitrateOptionIndex(6);

    expect(controller.viewModel.mp3BitrateOptionIndex, equals(6));

    controller.setMp3BitrateOptionIndex(999);

    expect(controller.viewModel.mp3BitrateOptionIndex, equals(13));
  });

  test(
    'savePreferences writes render fields using view model field names',
    () async {
      final preferences = _createPreferences();
      final viewModel =
          _createViewModel(
              filePath: r'C:\renders\mix.mp3',
              format: RenderAudioFormat.mp3,
            )
            ..sampleRate = 96000
            ..wavBitDepth = 16
            ..wavSampleFormat = RenderAudioSampleFormat.integer
            ..aiffBitDepth = 8
            ..flacBitDepth = 16
            ..flacCompressionLevel = 2
            ..oggQualityOptionIndex = 4
            ..mp3BitrateOptionIndex = 6
            ..rangeMode = RenderDialogRangeMode.loop
            ..includeTail = false
            ..statusText = 'Ready';

      await viewModel.savePreferences(preferences);

      final values = await preferences.getAll();
      expect(
        values.keys,
        unorderedEquals([
          'render.sampleRate',
          'render.wavBitDepth',
          'render.wavSampleFormat',
          'render.aiffBitDepth',
          'render.flacBitDepth',
          'render.flacCompressionLevel',
          'render.oggQualityOptionIndex',
          'render.mp3BitrateOptionIndex',
          'render.rangeMode',
          'render.includeTail',
        ]),
      );
      expect(values['render.sampleRate'], equals(96000));
      expect(values['render.wavBitDepth'], equals(16));
      expect(values['render.wavSampleFormat'], equals('integer'));
      expect(values['render.aiffBitDepth'], equals(8));
      expect(values['render.flacBitDepth'], equals(16));
      expect(values['render.flacCompressionLevel'], equals(2));
      expect(values['render.oggQualityOptionIndex'], equals(4));
      expect(values['render.mp3BitrateOptionIndex'], equals(6));
      expect(values['render.rangeMode'], equals('loop'));
      expect(values['render.includeTail'], isFalse);
      expect(values, isNot(contains('render.filePath')));
      expect(values, isNot(contains('render.format')));
      expect(values, isNot(contains('render.statusText')));
    },
  );

  test('loadPreferences restores saved render fields', () async {
    final preferences = _createPreferences({
      'render.sampleRate': 44100,
      'render.wavBitDepth': 24,
      'render.wavSampleFormat': 'integer',
      'render.aiffBitDepth': 16,
      'render.flacBitDepth': 16,
      'render.flacCompressionLevel': 7,
      'render.oggQualityOptionIndex': 3,
      'render.mp3BitrateOptionIndex': 5,
      'render.rangeMode': 'loop',
      'render.includeTail': false,
      'render.filePath': r'C:\renders\ignored.mp3',
      'render.format': 'mp3',
    });
    final viewModel = _createViewModel(filePath: r'C:\renders\mix.wav');

    await viewModel.loadPreferences(preferences);

    expect(viewModel.filePath, equals(r'C:\renders\mix.wav'));
    expect(viewModel.format, equals(RenderAudioFormat.wav));
    expect(viewModel.sampleRate, equals(44100));
    expect(viewModel.wavBitDepth, equals(24));
    expect(viewModel.wavSampleFormat, equals(RenderAudioSampleFormat.integer));
    expect(viewModel.aiffBitDepth, equals(16));
    expect(viewModel.flacBitDepth, equals(16));
    expect(viewModel.flacCompressionLevel, equals(7));
    expect(viewModel.oggQualityOptionIndex, equals(3));
    expect(viewModel.mp3BitrateOptionIndex, equals(5));
    expect(viewModel.rangeMode, equals(RenderDialogRangeMode.loop));
    expect(viewModel.includeTail, isFalse);
  });

  test(
    'loadPreferences keeps defaults for missing saved render fields',
    () async {
      final preferences = _createPreferences({'render.includeTail': false});
      final viewModel = _createViewModel(filePath: r'C:\renders\mix.wav');

      await viewModel.loadPreferences(preferences);

      expect(viewModel.sampleRate, equals(48000));
      expect(viewModel.wavBitDepth, equals(32));
      expect(
        viewModel.wavSampleFormat,
        equals(RenderAudioSampleFormat.floatingPoint),
      );
      expect(viewModel.aiffBitDepth, equals(24));
      expect(viewModel.flacBitDepth, equals(24));
      expect(viewModel.flacCompressionLevel, equals(5));
      expect(viewModel.oggQualityOptionIndex, equals(9));
      expect(viewModel.mp3BitrateOptionIndex, equals(13));
      expect(viewModel.rangeMode, equals(RenderDialogRangeMode.project));
      expect(viewModel.includeTail, isFalse);
    },
  );

  test('loadPreferences ignores invalid saved render fields', () async {
    final preferences = _createPreferences({
      'render.sampleRate': 12345,
      'render.wavBitDepth': 12,
      'render.wavSampleFormat': 'notAFormat',
      'render.aiffBitDepth': 32,
      'render.flacBitDepth': 8,
      'render.flacCompressionLevel': 9,
      'render.oggQualityOptionIndex': 11,
      'render.mp3BitrateOptionIndex': 14,
      'render.rangeMode': 'selection',
      'render.includeTail': 'false',
    });
    final viewModel = _createViewModel(filePath: r'C:\renders\mix.wav');

    await viewModel.loadPreferences(preferences);

    expect(viewModel.sampleRate, equals(48000));
    expect(viewModel.wavBitDepth, equals(32));
    expect(
      viewModel.wavSampleFormat,
      equals(RenderAudioSampleFormat.floatingPoint),
    );
    expect(viewModel.aiffBitDepth, equals(24));
    expect(viewModel.flacBitDepth, equals(24));
    expect(viewModel.flacCompressionLevel, equals(5));
    expect(viewModel.oggQualityOptionIndex, equals(9));
    expect(viewModel.mp3BitrateOptionIndex, equals(13));
    expect(viewModel.rangeMode, equals(RenderDialogRangeMode.project));
    expect(viewModel.includeTail, isTrue);
  });
}

RenderDialogController _createController({
  required String filePath,
  RenderAudioFormat format = RenderAudioFormat.wav,
  int sampleRate = 48000,
  SharedPreferencesAsync? preferences,
}) {
  return RenderDialogController(
    viewModel: _createViewModel(
      filePath: filePath,
      format: format,
      sampleRate: sampleRate,
    ),
    preferences: preferences ?? _createPreferences(),
  );
}

RenderDialogViewModel _createViewModel({
  required String filePath,
  RenderAudioFormat format = RenderAudioFormat.wav,
  int sampleRate = 48000,
}) {
  return RenderDialogViewModel(
    projectId: 'project',
    filePath: filePath,
    format: format,
    sampleRate: sampleRate,
  );
}

SharedPreferencesAsync _createPreferences([Map<String, Object>? values]) {
  SharedPreferencesAsyncPlatform.instance = values == null
      ? InMemorySharedPreferencesAsync.empty()
      : InMemorySharedPreferencesAsync.withData(values);
  return SharedPreferencesAsync();
}
