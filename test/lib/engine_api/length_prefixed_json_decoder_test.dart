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

import 'dart:convert';
import 'dart:typed_data';

import 'package:anthem/engine_api/length_prefixed_json_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _messageHeader(int messageLength) {
  final header = Uint8List(8);
  ByteData.sublistView(header).setUint64(0, messageLength, Endian.host);
  return header;
}

Uint8List _frameJson(Object? json) {
  final body = utf8.encode(jsonEncode(json));
  final frame = Uint8List(8 + body.length);
  frame.setRange(0, 8, _messageHeader(body.length));
  frame.setRange(8, frame.length, body);
  return frame;
}

void _addInChunks(
  LengthPrefixedJsonDecoder decoder,
  Uint8List bytes,
  Iterable<int> chunkLengths,
) {
  var offset = 0;

  for (final chunkLength in chunkLengths) {
    if (offset == bytes.length) {
      return;
    }

    final end = (offset + chunkLength).clamp(0, bytes.length);
    decoder.add(Uint8List.sublistView(bytes, offset, end));
    offset = end;
  }

  if (offset < bytes.length) {
    decoder.add(Uint8List.sublistView(bytes, offset));
  }
}

void main() {
  test('decodes a header and body split across arbitrary chunks', () {
    final decodedMessages = <Object?>[];
    final decoder = LengthPrefixedJsonDecoder(onMessage: decodedMessages.add);
    final message = <String, Object?>{
      'text': 'Héllo, 世界 𝄞',
      'values': [1, true, null],
    };
    final frame = _frameJson(message);

    _addInChunks(decoder, frame, List.filled(frame.length, 1));

    expect(decodedMessages, [message]);
  });

  test('decodes multiple messages from the same transport chunk', () {
    final decodedMessages = <Object?>[];
    final decoder = LengthPrefixedJsonDecoder(onMessage: decodedMessages.add);
    final frames = BytesBuilder(copy: false)
      ..add(_frameJson({'id': 1}))
      ..add(_frameJson(['second', 2]))
      ..add(_frameJson('third'));

    decoder.add(frames.takeBytes());

    expect(decodedMessages, [
      {'id': 1},
      ['second', 2],
      'third',
    ]);
  });

  test('continues across mixed header and message boundaries', () {
    final decodedMessages = <Object?>[];
    final decoder = LengthPrefixedJsonDecoder(onMessage: decodedMessages.add);
    final frames = BytesBuilder(copy: false)
      ..add(_frameJson({'first': true}))
      ..add(_frameJson({'second': true}));
    final bytes = frames.takeBytes();

    _addInChunks(decoder, bytes, [3, 8, 2, 17, 1]);

    expect(decodedMessages, [
      {'first': true},
      {'second': true},
    ]);
  });

  test('rejects empty messages', () {
    final decoder = LengthPrefixedJsonDecoder(onMessage: (_) {});

    expect(
      () => decoder.add(_messageHeader(0)),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects messages larger than the configured maximum', () {
    final decoder = LengthPrefixedJsonDecoder(
      onMessage: (_) {},
      maximumMessageLength: 32,
    );

    expect(
      () => decoder.add(_messageHeader(33)),
      throwsA(isA<FormatException>()),
    );

    final defaultDecoder = LengthPrefixedJsonDecoder(onMessage: (_) {});
    expect(
      () => defaultDecoder.add(_messageHeader(0x1_0000_0000)),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects malformed JSON split across chunks', () {
    final decoder = LengthPrefixedJsonDecoder(onMessage: (_) {});
    final body = utf8.encode('{"incomplete":');
    final frame = Uint8List(8 + body.length);
    frame.setRange(0, 8, _messageHeader(body.length));
    frame.setRange(8, frame.length, body);

    decoder.add(Uint8List.sublistView(frame, 0, frame.length - 1));

    expect(
      () => decoder.add(Uint8List.sublistView(frame, frame.length - 1)),
      throwsA(isA<FormatException>()),
    );
  });

  test('requires a valid maximum message length', () {
    expect(
      () =>
          LengthPrefixedJsonDecoder(onMessage: (_) {}, maximumMessageLength: 0),
      throwsArgumentError,
    );

    expect(
      () => LengthPrefixedJsonDecoder(
        onMessage: (_) {},
        maximumMessageLength: 0x1_0000_0000,
      ),
      throwsArgumentError,
    );
  });
}
