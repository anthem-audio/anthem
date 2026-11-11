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

import 'dart:io';
import 'dart:isolate';

/// Builds and runs `test/helpers/<name>.dart` with its own native libraries.
///
/// `dart run` rebundles native assets in the workspace's shared .dart_tool
/// directory, even when launched from a different working directory. Windows
/// cannot replace the DLL loaded by the parent test process. A private CLI
/// bundle lets each child run independently and is removed after it exits.
Future<ProcessResult> runBundledChild(
  String name,
  List<String> arguments,
) async {
  final libraryUri = await Isolate.resolvePackageUri(
    Uri.parse('package:anthem_native_ipc/anthem_native_ipc.dart'),
  );
  if (libraryUri == null) {
    throw StateError(
      'Could not resolve the anthem_native_ipc package directory.',
    );
  }

  final packageDirectory = File.fromUri(libraryUri).parent.parent;
  final source = packageDirectory.uri.resolve('test/helpers/$name.dart');
  final output = await Directory.systemTemp.createTemp('anthem_ipc_child_');
  try {
    final buildArguments = [
      'build',
      'cli',
      '--target',
      source.toFilePath(),
      '--output',
      output.path,
    ];
    final build = await Process.run(
      Platform.resolvedExecutable,
      buildArguments,
      workingDirectory: packageDirectory.path,
    );
    if (build.exitCode != 0) {
      throw ProcessException(
        Platform.resolvedExecutable,
        buildArguments,
        'Child bundle build failed.\nstdout: ${build.stdout}\nstderr: ${build.stderr}',
        build.exitCode,
      );
    }

    final extension = Platform.isWindows ? '.exe' : '';
    final executable = output.uri.resolve('bundle/bin/$name$extension');
    return await Process.run(
      executable.toFilePath(),
      arguments,
      workingDirectory: output.path,
    );
  } finally {
    if (await output.exists()) {
      await output.delete(recursive: true);
    }
  }
}
