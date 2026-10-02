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

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../bin/integration_test/test_plugin_manifest.dart';

void main() {
  late Directory directory;
  late File file;
  late Map<String, Object> manifest;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'anthem-plugin-manifest-',
    );
    final instrument = await Directory('${directory.path}/Instrument.vst3')
        .create();
    final effect = await Directory('${directory.path}/Effect.vst3').create();
    final helper = await File('${directory.path}/unconnected-engine')
        .writeAsString('fixture');
    manifest = TestPluginManifest(
      platform: Platform.operatingSystem,
      instrument: instrument.path,
      effect: effect.path,
      unconnectedEngine: helper.path,
    ).toJson();
    file = File('${directory.path}/test-plugins.json');
    await file.writeAsString(jsonEncode(manifest));
  });
  tearDown(() => directory.delete(recursive: true));
  Future<void> change(String key, Object value) async {
    manifest[key] = value;
    await file.writeAsString(jsonEncode(manifest));
  }

  test('reads native bundle paths and helper executable', () {
    final result = TestPluginManifest.read(file);
    expect(result.instrument, manifest['instrument']);
    expect(result.effect, manifest['effect']);
    expect(result.unconnectedEngine, manifest['unconnectedEngine']);
  });
  test('rejects fixtures built for another operating system', () async {
    await change('platform', 'other-platform');
    expect(() => TestPluginManifest.read(file), throwsFormatException);
  });
  test(
    'rejects a stale manifest after a plugin build directory was removed',
    () async {
      await Directory(manifest['instrument']! as String).delete();
      expect(() => TestPluginManifest.read(file), throwsFormatException);
    },
  );
  test('rejects an unavailable native helper', () async {
    await File(manifest['unconnectedEngine']! as String).delete();
    expect(() => TestPluginManifest.read(file), throwsFormatException);
  });
  test('rejects an unsupported manifest version', () async {
    await change('formatVersion', 2);
    expect(() => TestPluginManifest.read(file), throwsFormatException);
  });
  test('rejects a directory that is not a VST3 bundle', () async {
    await change('effect', directory.path);
    expect(() => TestPluginManifest.read(file), throwsFormatException);
  });
}
