/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

Uri getPackageRootPath() {
  final scriptPath = Platform.script;

  final dartToolIndex = scriptPath.pathSegments.indexOf('.dart_tool');
  if (dartToolIndex != -1) {
    return Uri.directory(
      (Platform.isWindows ? '' : '/') +
          scriptPath.pathSegments.take(dartToolIndex).join('/'),
    );
  }

  final scriptDirectory = File.fromUri(scriptPath).parent;
  final packageRoot =
      _findNearestPackageRoot(scriptDirectory) ??
      _findNearestPackageRoot(Directory.current);

  if (packageRoot != null) return packageRoot.uri;

  return Uri.directory(
    (Platform.isWindows ? '' : '/') +
        scriptPath.pathSegments.takeWhile((s) => s != '.dart_tool').join('/'),
  );
}

Directory? _findNearestPackageRoot(Directory startDirectory) {
  var directory = startDirectory.absolute;

  while (true) {
    final pubspecFile = File(_joinPath(directory.path, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) return directory;

    final parent = directory.parent;
    if (parent.path == directory.path) return null;

    directory = parent;
  }
}

String? findExecutable(
  String executableName, {
  List<String> additionalSearchDirectories = const [],
}) {
  final searchDirectories = <String>[
    ...additionalSearchDirectories,
    ..._getPathDirectories(),
  ];

  final candidateNames = _getExecutableCandidateNames(executableName);
  final visitedDirectories = <String>{};

  for (final directory in searchDirectories) {
    final normalizedDirectory = directory.trim();
    if (normalizedDirectory.isEmpty) continue;

    final directoryKey = Platform.isWindows
        ? normalizedDirectory.toLowerCase()
        : normalizedDirectory;
    if (!visitedDirectories.add(directoryKey)) continue;

    for (final candidateName in candidateNames) {
      final candidatePath = _joinPath(normalizedDirectory, candidateName);
      final candidateFile = File(candidatePath);
      if (candidateFile.existsSync()) {
        return candidateFile.path;
      }
    }
  }

  return null;
}

String? findLlvmExecutable(String executableName) {
  final configuredLlvmDirectory = Platform.environment['ANTHEM_LLVM_BIN'];

  return findExecutable(
    executableName,
    additionalSearchDirectories: [
      if (configuredLlvmDirectory != null && configuredLlvmDirectory.isNotEmpty)
        configuredLlvmDirectory,
      ...switch (Platform.operatingSystem) {
        'windows' => [
          r'C:\Program Files\LLVM\bin',
          r'C:\Program Files (x86)\LLVM\bin',
        ],
        'macos' => ['/opt/homebrew/opt/llvm/bin', '/usr/local/opt/llvm/bin'],
        _ => const <String>[],
      },
    ],
  );
}

String? findNinjaExecutable() {
  return findExecutable(
    'ninja',
    additionalSearchDirectories: [
      if (Platform.isWindows) r'C:\ProgramData\chocolatey\bin',
    ],
  );
}

List<String> _getPathDirectories() {
  final pathValue = Platform.environment['PATH'];
  if (pathValue == null || pathValue.isEmpty) return const [];

  final separator = Platform.isWindows ? ';' : ':';
  return pathValue.split(separator);
}

List<String> _getExecutableCandidateNames(String executableName) {
  if (!Platform.isWindows) return [executableName];

  final lowerExecutableName = executableName.toLowerCase();
  final candidateNames = <String>[executableName];

  if (!lowerExecutableName.endsWith('.exe')) {
    candidateNames.add('$executableName.exe');
  }

  return candidateNames;
}

String _joinPath(String directory, String name) {
  final separator = Platform.pathSeparator;
  if (directory.endsWith(separator)) {
    return '$directory$name';
  }

  return '$directory$separator$name';
}
