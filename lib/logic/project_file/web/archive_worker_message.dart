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

/// The client requests `open` or `file`, receiving `entries` or `done`.
/// While writing a file, each transferred `data` chunk waits for an `ack`.
/// Only one request and one output chunk may be in flight. Worker errors end
/// the pending request, after which the shared workflow cleans up and closes it.
extension type ArchiveWorkerMessage._(JSObject _) implements JSObject {
  external factory ArchiveWorkerMessage({
    required String operation,
    String? path,
    int? length,
    int? index,
    String? error,
  });

  external String get operation;
  external JSUint8Array? get bytes;
  external JSArray<ArchiveWorkerEntry> get entries;
  external String? get error;
  external String? get stack;
  external bool? get readError;
}

extension type ArchiveWorkerEntry._(JSObject _) implements JSObject {
  external String get name;
  external bool get isDirectory;
  external bool get isSymbolicLink;
  external int get length;
  external int get crc32;
}

const archiveTransferSize = 64 * 1024;
