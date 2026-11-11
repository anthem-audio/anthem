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

import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

YamlMap _loadPubspec(Uri repoRoot) {
  final Object? yaml = loadYaml(_readRepoFile(repoRoot, 'pubspec.yaml'));

  return yaml as YamlMap;
}

String _readRepoFile(Uri repoRoot, String path) {
  return File.fromUri(repoRoot.resolve(path)).readAsStringSync();
}

String _readYamlString(YamlMap yaml, String key) {
  return yaml[key].toString();
}

String _cmakeSetValue(String cmake, String variableName) {
  final pattern = RegExp(
    'set\\(${RegExp.escape(variableName)}\\s+"([^"]+)"\\)',
  );
  final match = pattern.firstMatch(cmake);

  if (match == null) {
    fail('Expected CMake to define $variableName with set(...).');
  }

  return match.group(1)!;
}

String _issDefineValue(String iss, String defineName) {
  final pattern = RegExp(
    '#define\\s+${RegExp.escape(defineName)}\\s+"([^"]+)"',
  );
  final match = pattern.firstMatch(iss);

  if (match == null) {
    fail('Expected .iss to define $defineName with #define ...');
  }

  return match.group(1)!;
}

String _xmlAttributeValue(
  String xml, {
  required String elementName,
  required String attributeName,
}) {
  final pattern = RegExp(
    '<${RegExp.escape(elementName)}\\b[^>]*\\b'
    '${RegExp.escape(attributeName)}\\s*=\\s*["\']([^"\']+)["\']',
  );
  final match = pattern.firstMatch(xml);

  if (match == null) {
    fail('Expected XML to contain <$elementName> with $attributeName.');
  }

  return match.group(1)!;
}

void main() {
  final repoRoot = Directory.current.uri;
  final pubspec = _loadPubspec(repoRoot);
  final pubspecVersion = _readYamlString(pubspec, 'version');
  final parsedPubspecVersion = Version.parse(pubspecVersion);
  final pubspecVersionCore =
      '${parsedPubspecVersion.major}.'
      '${parsedPubspecVersion.minor}.'
      '${parsedPubspecVersion.patch}';

  test('Dart version matches pubspec version', () {
    expect(anthemVersion, pubspecVersion);
  });

  test('Project file software version matches pubspec version', () {
    expect(currentProjectFileSoftwareVersion, pubspecVersion);
    expect(currentProjectFileVersion.toString(), pubspecVersion);
  });

  test('Inno Setup versions are derived from the pubspec version', () {
    final iss = _readRepoFile(repoRoot, 'packaging/windows/anthem.iss');
    final appVersion = _issDefineValue(iss, 'MyAppVersion');
    final numericVersion = _issDefineValue(iss, 'MyAppVersionNumeric');
    final numericVersionParts = numericVersion
        .split('.')
        .map(int.parse)
        .toList(growable: false);

    expect(appVersion, pubspecVersion);
    expect(numericVersion, matches(RegExp(r'^\d+\.\d+\.\d+\.\d+$')));
    expect(numericVersionParts.take(3).join('.'), pubspecVersionCore);
  });

  test('CMake engine versions are derived from the pubspec version', () {
    final cmake = _readRepoFile(repoRoot, 'engine/CMakeLists.txt');

    expect(_cmakeSetValue(cmake, 'ANTHEM_VERSION'), pubspecVersion);
    expect(_cmakeSetValue(cmake, 'ANTHEM_VERSION_CORE'), pubspecVersionCore);
    expect(cmake, contains('VERSION \${ANTHEM_VERSION_CORE}'));
    expect(
      cmake,
      matches(
        RegExp(
          r'target_compile_definitions\(\s*'
          r'AnthemEngine\s+PRIVATE\s+'
          r'ANTHEM_VERSION_STRING="\$\{ANTHEM_VERSION\}"\s*'
          r'\)',
        ),
      ),
    );
  });

  test('Engine runtime version uses the CMake-provided display version', () {
    final mainCpp = _readRepoFile(repoRoot, 'engine/src/main.cpp');

    expect(mainCpp, contains('return ANTHEM_VERSION_STRING;'));
  });

  test('Flatpak AppStream release version matches pubspec version', () {
    final metainfo = _readRepoFile(
      repoRoot,
      'packaging/flatpak/io.github.anthem_audio.Anthem.metainfo.xml',
    );

    expect(
      _xmlAttributeValue(
        metainfo,
        elementName: 'release',
        attributeName: 'version',
      ),
      pubspecVersion,
    );
  });
}
