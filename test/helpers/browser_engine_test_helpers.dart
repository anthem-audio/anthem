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

/// Loads real build outputs served by Flutter's test-directory file handler.
/// Build them with `dart run anthem:cli engine build --debug --wasm` first.
Future<void> loadBrowserModule(String name, {bool usesWorkers = false}) async {
  if (globalContext.getProperty(name.toJS).isA<JSFunction>()) return;
  final source = '/.engine/$name.js';
  var scriptUrl = source;
  if (usesWorkers) {
    // Flutter serves JS fixtures without COEP, which blocks worker startup in
    // its isolated iframe. Blob workers inherit the iframe's isolation policy.
    // Keep this URL alive for replacement engines throughout the suite.
    final response = await web.window.fetch(source.toJS).toDart;
    if (!response.ok) throw StateError('Could not load $source.');
    final text = await response.text().toDart;
    scriptUrl = web.URL.createObjectURL(
      web.Blob([text].toJS, web.BlobPropertyBag(type: 'text/javascript')),
    );
  }
  final completed = Completer<void>();
  final script = web.HTMLScriptElement()..src = scriptUrl;
  script.onload = ((web.Event _) => completed.complete()).toJS;
  script.onerror = ((web.Event _) => completed.completeError(
    StateError(
      'Build the browser engine before running this suite: $name.js is missing.',
    ),
  )).toJS;
  web.document.head!.appendChild(script);
  try {
    await completed.future;
    if (usesWorkers) {
      final factory = globalContext.getProperty<JSFunction>(name.toJS);
      globalContext.setProperty(
        name.toJS,
        ((JSObject? incoming) {
          final options = incoming ?? JSObject();
          options.setProperty(
            'locateFile'.toJS,
            ((
              JSString file,
              JSString _,
            ) => '/.engine/${file.toDart}'.toJS).toJS,
          );
          return factory.callAsFunction(null, options);
        }).toJS,
      );
    }
  } finally {
    script.remove();
  }
}
