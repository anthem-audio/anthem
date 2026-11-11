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

import 'package:flutter/services.dart';

/// Both scripts are ordinary package assets in app builds and browser tests.
/// A Blob worker also avoids the test server's missing worker COEP headers.
/// The upstream bundle defines `zip` for the worker script to use.
Future<String> loadArchiveWorkerSource() async {
  final scripts = await Future.wait([
    rootBundle.loadString(
      'packages/anthem/logic/project_file/web/vendor/zipjs/zip-native.min.js',
    ),
    rootBundle.loadString(
      'packages/anthem/logic/project_file/web/project_archive_worker.js',
    ),
  ]);
  return scripts.join('\n');
}
