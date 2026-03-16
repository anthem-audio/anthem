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

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rebuilds generated files when tracked part files and imported libraries change',
    () async {
      final codegenPackageRoot = _findCodegenPackageRoot();
      final fixturePackage = await _TempCodegenPackage.create(
        codegenPackageRoot: codegenPackageRoot,
      );
      addTearDown(fixturePackage.dispose);

      await fixturePackage.writeFiles({
        'pubspec.yaml': _fixturePubspec(
          codegenPackagePath: codegenPackageRoot.path.replaceAll('\\', '/'),
        ),
        'lib/message_definition.dart': _messageDefinitionWithInt,
        'lib/messages.dart': _messagesLibrary,
        'lib/imported.dart': _plainImportedValue,
        'lib/root.dart': _rootLibrary,
      });

      await fixturePackage.pubGet();
      await fixturePackage.build();

      final initialMessagesG = await fixturePackage.readFile(
        'lib/messages.g.dart',
      );
      expect(initialMessagesG, contains("(json['count'] as num).toInt()"));

      final initialRootG = await fixturePackage.readFile('lib/root.g.dart');
      expect(initialRootG, isNot(contains('ImportedValue.fromJson')));

      final initialRootHeader = await fixturePackage.readFile(
        'engine/src/generated/lib/root.h',
      );
      expect(initialRootHeader, contains('TYPE_ERROR_UNKNOWN_TYPE'));
      expect(initialRootHeader, isNot(contains('#include "imported.h"')));

      await fixturePackage.writeFile(
        'lib/message_definition.dart',
        _messageDefinitionWithString,
      );
      await fixturePackage.build();

      final updatedMessagesG = await fixturePackage.readFile(
        'lib/messages.g.dart',
      );
      expect(updatedMessagesG, isNot(equals(initialMessagesG)));
      expect(updatedMessagesG, contains("json['count'] as String"));

      await fixturePackage.writeFile(
        'lib/imported.dart',
        _generatedImportedValue,
      );
      await fixturePackage.build();

      final updatedRootG = await fixturePackage.readFile('lib/root.g.dart');
      expect(updatedRootG, isNot(equals(initialRootG)));
      expect(updatedRootG, contains('ImportedValue.fromJson'));
      expect(updatedRootG, contains('child?.toJson'));

      final updatedRootHeader = await fixturePackage.readFile(
        'engine/src/generated/lib/root.h',
      );
      expect(updatedRootHeader, isNot(equals(initialRootHeader)));
      expect(updatedRootHeader, contains('#include "imported.h"'));
      expect(
        updatedRootHeader,
        contains('std::optional<std::shared_ptr<ImportedValue>> child;'),
      );
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    'rebuilds generated module headers when exported libraries change',
    () async {
      final codegenPackageRoot = _findCodegenPackageRoot();
      final fixturePackage = await _TempCodegenPackage.create(
        codegenPackageRoot: codegenPackageRoot,
      );
      addTearDown(fixturePackage.dispose);

      await fixturePackage.writeFiles({
        'pubspec.yaml': _fixturePubspec(
          codegenPackagePath: codegenPackageRoot.path.replaceAll('\\', '/'),
        ),
        'lib/module.dart': _moduleLibrary,
        'lib/existing.dart': _annotatedExistingEnum,
        'lib/candidate.dart': _plainCandidateEnum,
      });

      await fixturePackage.pubGet();
      await fixturePackage.build();

      final initialModuleHeader = await fixturePackage.readFile(
        'engine/src/generated/lib/module.h',
      );
      expect(initialModuleHeader, contains('#include "existing.h"'));
      expect(initialModuleHeader, isNot(contains('#include "candidate.h"')));

      await fixturePackage.writeFile(
        'lib/candidate.dart',
        _annotatedCandidateEnum,
      );
      await fixturePackage.build();

      final updatedModuleHeader = await fixturePackage.readFile(
        'engine/src/generated/lib/module.h',
      );
      expect(updatedModuleHeader, isNot(equals(initialModuleHeader)));
      expect(updatedModuleHeader, contains('#include "existing.h"'));
      expect(updatedModuleHeader, contains('#include "candidate.h"'));
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

class _TempCodegenPackage {
  final Directory directory;

  _TempCodegenPackage._(this.directory);

  static Future<_TempCodegenPackage> create({
    required Directory codegenPackageRoot,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'anthem_codegen_dependency_tracking_',
    );

    final package = _TempCodegenPackage._(tempDir);
    await package.writeFiles({
      'build.yaml': _fixtureBuildYaml,
      'pubspec.yaml': _fixturePubspec(
        codegenPackagePath: codegenPackageRoot.path.replaceAll('\\', '/'),
      ),
    });

    return package;
  }

  Future<void> dispose() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> writeFiles(Map<String, String> files) async {
    for (final entry in files.entries) {
      await writeFile(entry.key, entry.value);
    }
  }

  Future<void> writeFile(String relativePath, String contents) async {
    final file = File(_resolve(relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  Future<String> readFile(String relativePath) async {
    final file = File(_resolve(relativePath));
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Expected generated file to exist: $relativePath',
    );
    return file.readAsString();
  }

  Future<void> pubGet() {
    return _runFlutterCommand(['pub', 'get']);
  }

  Future<void> build() {
    return _runFlutterCommand([
      'pub',
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ]);
  }

  Future<void> _runFlutterCommand(List<String> args) async {
    // The fixture depends on anthem_codegen, which currently has a Flutter SDK
    // dependency, so using the Flutter tool here keeps dependency resolution
    // consistent with the main repo.
    final result = await Process.run(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      args,
      workingDirectory: directory.path,
    );

    expect(
      result.exitCode,
      0,
      reason:
          '''
Command failed: flutter ${args.join(' ')}
Working directory: ${directory.path}

stdout:
${result.stdout}

stderr:
${result.stderr}
''',
    );
  }

  String _resolve(String relativePath) {
    return directory.uri
        .resolve(relativePath)
        .toFilePath(windows: Platform.isWindows);
  }
}

Directory _findCodegenPackageRoot() {
  Directory? current = Directory.current.absolute;

  while (current != null) {
    if (_isCodegenPackage(current)) {
      return current;
    }

    final codegenChild = Directory(
      current.uri.resolve('codegen/').toFilePath(windows: Platform.isWindows),
    );
    if (_isCodegenPackage(codegenChild)) {
      return codegenChild;
    }

    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }

  throw StateError('Could not locate the anthem_codegen package root.');
}

bool _isCodegenPackage(Directory directory) {
  final pubspecFile = File(
    directory.uri
        .resolve('pubspec.yaml')
        .toFilePath(windows: Platform.isWindows),
  );

  if (!pubspecFile.existsSync()) {
    return false;
  }

  final pubspec = pubspecFile.readAsStringSync();
  return pubspec.contains('name: anthem_codegen');
}

String _fixturePubspec({required String codegenPackagePath}) =>
    '''
name: dependency_tracking_fixture
publish_to: 'none'

environment:
  sdk: '>=3.11.0 <4.0.0'

dependencies:
  anthem_codegen:
    path: '$codegenPackagePath'

dev_dependencies:
  build_runner: ^2.11.1
''';

const _messagesLibrary = r'''
import 'package:anthem_codegen/include.dart';

part 'message_definition.dart';
part 'messages.g.dart';

@AnthemModel(serializable: true)
class Message extends _Message with _$MessageAnthemModelMixin {
  Message();

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageAnthemModelMixin.fromJson(json);
}
''';

const _messageDefinitionWithInt = '''
part of 'messages.dart';

class _Message {
  late int count;
}
''';

const _messageDefinitionWithString = '''
part of 'messages.dart';

class _Message {
  late String count;
}
''';

const _rootLibrary = r'''
import 'package:anthem_codegen/include.dart';

import 'imported.dart';

part 'root.g.dart';

@AnthemModel(serializable: true, generateCpp: true)
class RootModel extends _RootModel with _$RootModelAnthemModelMixin {
  RootModel();

  factory RootModel.fromJson(Map<String, dynamic> json) =>
      _$RootModelAnthemModelMixin.fromJson(json);
}

class _RootModel {
  ImportedValue? child;
}
''';

const _plainImportedValue = '''
class ImportedValue {}
''';

const _generatedImportedValue = r'''
import 'package:anthem_codegen/include.dart';

part 'imported.g.dart';

@AnthemModel(serializable: true, generateCpp: true)
class ImportedValue extends _ImportedValue with _$ImportedValueAnthemModelMixin {
  ImportedValue();

  factory ImportedValue.fromJson(Map<String, dynamic> json) =>
      _$ImportedValueAnthemModelMixin.fromJson(json);
}

class _ImportedValue {
  late String label;
}
''';

const _moduleLibrary = '''
@GenerateCppModuleFile()
library;

import 'package:anthem_codegen/include.dart';

export 'existing.dart';
export 'candidate.dart';
''';

const _annotatedExistingEnum = '''
import 'package:anthem_codegen/include.dart';

@AnthemEnum()
enum ExistingEnum { one }
''';

const _plainCandidateEnum = '''
enum CandidateEnum { one }
''';

const _annotatedCandidateEnum = '''
import 'package:anthem_codegen/include.dart';

@AnthemEnum()
enum CandidateEnum { one }
''';

const _fixtureBuildYaml = '''
targets:
  \$default:
    builders:
      anthem_codegen:anthemDartModelGeneratorBuilder:
        enabled: true
      anthem_codegen:cppModelBuilder:
        enabled: true
''';
