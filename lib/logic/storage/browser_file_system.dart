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

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:anthem/helpers/emscripten_module.dart';
import 'package:path/path.dart' as path;

/// Hosts browser working files independently of audio engine sessions.
///
/// The filesystem lives in a small Emscripten module with no audio engine.
/// Dart accesses it directly, and engine modules mount it through PROXYFS.
/// All filesystem calls run on the browser thread; C++ file I/O is proxied
/// there by Emscripten. Audio callbacks must never perform file I/O.
///
/// Each project has its own directory under [root]. Files remain available
/// through engine shutdown and restart, until project storage removes them.
/// This backend uses MEMFS: working files occupy memory and are lost on page
/// reload. Exporting a project must copy its files into the downloaded archive.
class BrowserFileSystem {
  static const root = '/anthem';
  static final paths = path.Context(style: path.Style.posix, current: root);
  static Future<BrowserFileSystem>? _opening;

  final JSObject fs;

  BrowserFileSystem._(this.fs);

  /// The current initialization future, or null until [instance] is requested.
  static Future<BrowserFileSystem>? get existingInstance => _opening;

  static Future<BrowserFileSystem> get instance =>
      _opening ??= _open().catchError((Object error, StackTrace stack) {
        _opening = null;
        Error.throwWithStackTrace(error, stack);
      });

  static Future<BrowserFileSystem> _open() async {
    final factory = await loadEmscriptenFactory('AnthemFileSystem');
    final module =
        await (factory.callAsFunction() as JSPromise<JSObject>).toDart;
    final result = BrowserFileSystem._(module.getProperty<JSObject>('FS'.toJS));
    result.fs.callMethod<JSAny?>('mkdirTree'.toJS, root.toJS);
    return result;
  }

  static String absolutePath(String file) {
    final absolute = paths.normalize(paths.absolute(file));
    if (absolute != root && !paths.isWithin(root, absolute)) {
      throw ArgumentError.value(file, 'file', 'Expected a path under $root.');
    }
    return absolute;
  }

  /// Mounts the working filesystem at the same path in an engine module.
  /// Called during preRun, before the engine's C++ entry point can use files.
  void mount(JSObject engine) {
    final engineFs = engine.getProperty<JSObject>('FS'.toJS);
    engineFs.callMethod<JSAny?>('mkdirTree'.toJS, root.toJS);
    final options = JSObject()
      ..setProperty('root'.toJS, root.toJS)
      ..setProperty('fs'.toJS, fs);
    engineFs.callMethod<JSAny?>(
      'mount'.toJS,
      engine.getProperty<JSObject>('PROXYFS'.toJS),
      options,
      root.toJS,
    );
  }

  /// Detaches an engine after its runtime has exited, leaving working files.
  void unmount(JSObject engine) {
    engine
        .getProperty<JSObject>('FS'.toJS)
        .callMethod<JSAny?>('unmount'.toJS, root.toJS);
  }

  Uint8List readFile(String file) => Uint8List.fromList(
    fs
        .callMethod<JSUint8Array>('readFile'.toJS, absolutePath(file).toJS)
        .toDart,
  );

  void writeFile(String file, List<int> bytes) => fs.callMethod<JSAny?>(
    'writeFile'.toJS,
    absolutePath(file).toJS,
    Uint8List.fromList(bytes).toJS,
  );
}
