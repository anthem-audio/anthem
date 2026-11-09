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

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

final _scripts = <Uri, Future<void>>{};

/// Loads an Emscripten module factory without starting a module instance.
/// Concurrent callers share the script load; a failed load can be retried.
Future<JSFunction> loadEmscriptenFactory(String name) async {
  final existing = globalContext.getProperty(name.toJS);
  if (existing.isA<JSFunction>()) return existing as JSFunction;

  final uri = Uri.parse(web.document.baseURI).resolve('engine/$name.js');
  await _scripts.putIfAbsent(uri, () => _loadScript(uri));
  final factory = globalContext.getProperty(name.toJS);
  if (!factory.isA<JSFunction>()) {
    _scripts.remove(uri);
    throw StateError('$uri did not define the $name module factory.');
  }
  return factory as JSFunction;
}

Future<void> _loadScript(Uri uri) async {
  final completed = Completer<void>();
  final script = web.HTMLScriptElement()..src = uri.toString();
  script.onload = ((web.Event _) => completed.complete()).toJS;
  script.onerror = ((web.Event _) {
    completed.completeError(StateError('Could not load $uri.'));
  }).toJS;
  web.document.head!.appendChild(script);
  try {
    await completed.future;
  } catch (_) {
    _scripts.remove(uri);
    rethrow;
  } finally {
    script.onload = null;
    script.onerror = null;
    script.remove();
  }
}
