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

class AnthemLogManager {
  static const engineLogSessionEnvironmentKey = 'ANTHEM_LOG_SESSION_DIR';

  static final AnthemLogManager instance = AnthemLogManager._();

  AnthemLogManager._();

  String? get activeSessionDirectoryPath => null;

  Map<String, String> get childProcessEnvironment => const {};

  Future<void> initialize({Object? rootDirectory}) async {}

  Future<void> flush() async {}

  Future<void> dispose() async {}

  Future<String> exportLogs({required String outputPath}) {
    throw UnsupportedError('Log export is not available on this platform.');
  }
}
