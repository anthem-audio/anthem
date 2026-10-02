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

import 'dart:convert';
import 'dart:io';

/// Explicit fixture paths produced by `engine build-test-plugins`.
class TestPluginManifest {
  final String platform;
  final String instrument;
  final String effect;
  final String unconnectedEngine;

  TestPluginManifest({
    required this.platform,
    required this.instrument,
    required this.effect,
    required this.unconnectedEngine,
  });

  static TestPluginManifest read(File file, {String? expectedPlatform}) {
    final data = jsonDecode(file.readAsStringSync());
    if (data is! Map || data['formatVersion'] != 1) {
      throw FormatException('Invalid test plugin manifest: ${file.path}');
    }
    final platform = data['platform'];
    if (platform != (expectedPlatform ?? Platform.operatingSystem)) {
      throw FormatException(
        'Test plugins were built for $platform, not ${expectedPlatform ?? Platform.operatingSystem}.',
      );
    }
    String requirePath(String name, {bool plugin = false}) {
      final value = data[name];
      if (value is! String ||
          value.isEmpty ||
          (!File(value).existsSync() && !Directory(value).existsSync()) ||
          (plugin && !value.endsWith('.vst3')) ||
          (!plugin && !File(value).existsSync())) {
        throw FormatException(
          'Missing or invalid $name fixture in ${file.path}. Rebuild with dart run anthem:cli engine build-test-plugins.',
        );
      }
      return value;
    }

    return TestPluginManifest(
      platform: platform as String,
      instrument: requirePath('instrument', plugin: true),
      effect: requirePath('effect', plugin: true),
      unconnectedEngine: requirePath('unconnectedEngine'),
    );
  }

  Map<String, Object> toJson() => {
    'formatVersion': 1,
    'platform': platform,
    'instrument': instrument,
    'effect': effect,
    'unconnectedEngine': unconnectedEngine,
  };
}
