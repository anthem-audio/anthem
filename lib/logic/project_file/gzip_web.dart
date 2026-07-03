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
import 'dart:typed_data';

import 'package:web/web.dart';

Future<Uint8List> compressGzip(Uint8List data) {
  final compressionStream = CompressionStream('gzip');

  return _transform(
    data,
    ReadableWritablePair(
      readable: compressionStream.readable,
      writable: compressionStream.writable,
    ),
  );
}

Future<Uint8List> decompressGzip(Uint8List data) {
  final decompressionStream = DecompressionStream('gzip');

  return _transform(
    data,
    ReadableWritablePair(
      readable: decompressionStream.readable,
      writable: decompressionStream.writable,
    ),
  );
}

Future<Uint8List> _transform(
  Uint8List data,
  ReadableWritablePair transform,
) async {
  final reader =
      _blob(data).stream().pipeThrough(transform).getReader()
          as ReadableStreamDefaultReader;

  final output = BytesBuilder(copy: false);

  while (true) {
    final chunk = await reader.read().toDart;
    final value = chunk.value as JSUint8Array?;

    if (value != null) {
      output.add(value.toDart);
    }

    if (chunk.done) {
      return output.takeBytes();
    }
  }
}

Blob _blob(Uint8List data) {
  return Blob(
    [data.toJS].toJS,
    BlobPropertyBag(type: 'application/octet-stream'),
  );
}
