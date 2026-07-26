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
import 'dart:math';
import 'dart:typed_data';

/// Decodes a stream of length-prefixed UTF-8 JSON messages.
///
/// Each message begins with an unsigned 64-bit length in host byte order. The
/// message body is streamed directly into Dart's UTF-8 JSON decoder, so neither
/// socket chunks nor complete message bodies need to be combined into a
/// contiguous buffer first.
class LengthPrefixedJsonDecoder {
  static const _headerLength = 8;

  /// Limits the resources that a single message can consume. This also
  /// prevents a corrupt header from leaving the decoder waiting indefinitely
  /// for an implausibly large message body.
  static const defaultMaximumMessageLength = 256 * 1024 * 1024;

  final void Function(Object? json) onMessage;
  final int maximumMessageLength;

  final Uint8List _header = Uint8List(_headerLength);
  int _headerBytesRead = 0;

  ByteConversionSink? _messageSink;
  int _messageBytesRemaining = 0;

  LengthPrefixedJsonDecoder({
    required this.onMessage,
    this.maximumMessageLength = defaultMaximumMessageLength,
  }) {
    if (maximumMessageLength <= 0 || maximumMessageLength > 0xFFFF_FFFF) {
      throw ArgumentError.value(
        maximumMessageLength,
        'maximumMessageLength',
        'must be between 1 and 2^32 - 1',
      );
    }
  }

  /// Adds the next bytes from the transport.
  ///
  /// A chunk may contain a partial header, a partial message body, multiple
  /// messages, or any combination of those. Decoded messages are delivered
  /// synchronously through [onMessage].
  void add(Uint8List chunk) {
    var chunkOffset = 0;

    while (chunkOffset < chunk.length) {
      if (_messageSink == null) {
        chunkOffset = _readHeader(chunk, chunkOffset);
        if (_headerBytesRead < _headerLength) {
          return;
        }

        _startMessage();
      }

      final bytesToRead = min(
        _messageBytesRemaining,
        chunk.length - chunkOffset,
      );
      final messageEnd = chunkOffset + bytesToRead;
      final isLastSlice = bytesToRead == _messageBytesRemaining;
      final messageSink = _messageSink!;

      if (isLastSlice) {
        // Closing the conversion delivers the decoded value synchronously.
        // Reset first so the decoder remains in a consistent state if the
        // callback re-enters [add].
        _messageSink = null;
        _messageBytesRemaining = 0;
      } else {
        _messageBytesRemaining -= bytesToRead;
      }

      messageSink.addSlice(chunk, chunkOffset, messageEnd, isLastSlice);
      chunkOffset = messageEnd;
    }
  }

  int _readHeader(Uint8List chunk, int chunkOffset) {
    final bytesToRead = min(
      _headerLength - _headerBytesRead,
      chunk.length - chunkOffset,
    );

    _header.setRange(
      _headerBytesRead,
      _headerBytesRead + bytesToRead,
      chunk,
      chunkOffset,
    );
    _headerBytesRead += bytesToRead;

    return chunkOffset + bytesToRead;
  }

  void _startMessage() {
    final byteData = ByteData.sublistView(_header);
    final lowOffset = Endian.host == Endian.little ? 0 : 4;
    final highOffset = Endian.host == Endian.little ? 4 : 0;
    final low = byteData.getUint32(lowOffset, Endian.host);
    final high = byteData.getUint32(highOffset, Endian.host);

    _headerBytesRead = 0;

    if (high != 0 || low > maximumMessageLength) {
      throw FormatException(
        'Message length exceeds the maximum supported length of '
        '$maximumMessageLength bytes.',
      );
    }

    if (low == 0) {
      throw const FormatException('Message length must be greater than zero.');
    }

    _messageBytesRemaining = low;

    final jsonSink = json.decoder.startChunkedConversion(
      _DecodedMessageSink(onMessage),
    );
    _messageSink = utf8.decoder.startChunkedConversion(jsonSink);
  }
}

class _DecodedMessageSink implements Sink<Object?> {
  final void Function(Object? json) onMessage;

  _DecodedMessageSink(this.onMessage);

  @override
  void add(Object? json) => onMessage(json);

  @override
  void close() {}
}
