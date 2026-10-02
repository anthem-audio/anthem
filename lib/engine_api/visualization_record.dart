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

import 'dart:convert';
import 'dart:typed_data';

import 'package:anthem/engine_api/messages/messages.dart';

const maximumVisualizationRecordBytes = 1024 * 1024;
const visualizationHistoryDuration = Duration(milliseconds: 250);

/// Owned visualization values decoded while a shared-memory record is acquired.
final class VisualizationRecord {
  final int sequence;
  final int generation;
  final double sampleRate;
  final int newestSampleTimestamp;
  final VisualizationUpdateEvent update;
  final bool discontinuity;

  const VisualizationRecord({
    required this.sequence,
    required this.generation,
    required this.sampleRate,
    required this.newestSampleTimestamp,
    required this.update,
    this.discontinuity = false,
  });
}

VisualizationRecord decodeVisualizationRecord(Uint8List bytes) {
  if (bytes.length < 40 || bytes.length > maximumVisualizationRecordBytes) {
    throw const FormatException('Invalid visualization record size.');
  }
  final reader = _RecordDecoder(bytes);
  if (reader.uint32() != 0x31564941 || reader.uint32() != 1) {
    throw const FormatException('Unsupported visualization record format.');
  }
  final sequence = reader.uint32();
  final generation = reader.uint64();
  final sampleRate = reader.float64();
  final newest = reader.int64();
  final itemCount = reader.uint32();
  if (!sampleRate.isFinite ||
      sampleRate > 1000000 ||
      sampleRate <= 0 ||
      newest < 0 ||
      itemCount > reader.remaining ~/ 12) {
    throw const FormatException('Invalid visualization record header.');
  }
  final items = <VisualizationItem>[];
  final ids = <String>{};
  for (var itemIndex = 0; itemIndex < itemCount; itemIndex++) {
    final idLength = reader.uint32();
    final typeIndex = reader.uint32();
    final count = reader.uint32();
    if (idLength == 0 ||
        idLength > 4096 ||
        typeIndex >= VisualizationValueType.values.length ||
        count > 2048) {
      throw const FormatException('Invalid visualization item header.');
    }
    final id = reader.text(idLength);
    if (!ids.add(id)) {
      throw const FormatException('Duplicate visualization item ID.');
    }
    final type = VisualizationValueType.values[typeIndex];
    final (timestamps, values) = switch (type) {
      VisualizationValueType.doubleValue => reader.numericSamples<double>(
        count,
        newest,
        reader.float64,
      ),
      VisualizationValueType.intValue => reader.numericSamples<int>(
        count,
        newest,
        reader.int64,
      ),
    };
    items.add(
      VisualizationItem(
        id: id,
        valueType: type,
        values: values,
        sampleTimestamps: timestamps,
      ),
    );
  }
  if (reader.remaining != 0) {
    throw const FormatException('Trailing bytes in visualization record.');
  }
  return VisualizationRecord(
    sequence: sequence,
    generation: generation,
    sampleRate: sampleRate,
    newestSampleTimestamp: newest,
    update: VisualizationUpdateEvent(id: -1, items: items),
  );
}

final class _RecordDecoder {
  final Uint8List bytes;
  final ByteData data;
  int offset = 0;

  _RecordDecoder(this.bytes) : data = ByteData.sublistView(bytes);
  int get remaining => bytes.length - offset;
  int take(int count) {
    if (count < 0 || count > remaining) {
      throw const FormatException('Truncated visualization record.');
    }
    final start = offset;
    offset += count;
    return start;
  }

  int uint32() => data.getUint32(take(4), Endian.little);
  int uint64() => _integer64(signed: false);
  int int64() => _integer64(signed: true);

  int _integer64({required bool signed}) {
    final start = take(8);
    // JavaScript Dart has no ByteData 64-bit integer accessors. Decode words
    // arithmetically there and reject values that cannot be represented exactly.
    // Native and WebAssembly Dart retain the full signed 64-bit range.
    if (!identical(1, 1.0)) {
      return signed
          ? data.getInt64(start, Endian.little)
          : data.getUint64(start, Endian.little);
    }
    final low = data.getUint32(start, Endian.little);
    final high = signed
        ? data.getInt32(start + 4, Endian.little)
        : data.getUint32(start + 4, Endian.little);
    final value = high * 4294967296 + low;
    if (value < -9007199254740991 || value > 9007199254740991) {
      throw const FormatException(
        'Visualization integer exceeds JavaScript precision.',
      );
    }
    return value;
  }

  double float64() => data.getFloat64(take(8), Endian.little);

  (List<int>, List<T>) numericSamples<T>(
    int count,
    int newest,
    T Function() readValue,
  ) {
    if (count > remaining ~/ 16) {
      throw const FormatException('Truncated visualization samples.');
    }
    final timestamps = <int>[];
    final values = <T>[];
    var previousTimestamp = -1;
    for (var i = 0; i < count; i++) {
      final timestamp = int64();
      if (timestamp < previousTimestamp ||
          timestamp < 0 ||
          timestamp > newest) {
        throw const FormatException('Invalid visualization sample timestamp.');
      }
      previousTimestamp = timestamp;
      timestamps.add(timestamp);
      values.add(readValue());
    }
    return (timestamps, values);
  }

  String text(int count) {
    final start = take(count);
    return utf8.decode(Uint8List.sublistView(bytes, start, start + count));
  }
}

/// The platform adapters supply only acquire/release. Scheduling and decoding
/// are shared and have no dependency on Flutter.
final class VisualizationRecordConsumer {
  final Uint8List? Function() tryAcquire;
  final void Function() release;
  final void Function(VisualizationRecord) onRecord;
  final int Function()? availableBytes;
  final Duration Function() _now;
  final int maximumRecordsPerPass;
  final Duration maximumPassDuration;

  int recordsRead = 0;
  int bytesRead = 0;
  int skippedSamples = 0;
  int skippedRecords = 0;
  int queueByteHighWater = 0;
  int discontinuities = 0;
  int maximumDrainMicroseconds = 0;
  bool reachedBudget = false;
  int? _generation;
  int? _sequence;
  Duration? _lastPollTime;
  Duration? _lastRecordTime;

  VisualizationRecordConsumer({
    required this.tryAcquire,
    required this.release,
    required this.onRecord,
    this.availableBytes,
    Duration Function()? now,
    this.maximumRecordsPerPass = 256,
    this.maximumPassDuration = const Duration(milliseconds: 2),
  }) : _now = now ?? _monotonicNow;

  static final _clock = Stopwatch()..start();
  static Duration _monotonicNow() => _clock.elapsed;

  void poll() {
    final started = _now();
    final queued = availableBytes?.call() ?? 0;
    if (queued > queueByteHighWater) queueByteHighWater = queued;
    var reset =
        _lastPollTime != null &&
        started - _lastPollTime! > visualizationHistoryDuration;
    _lastPollTime = started;
    reachedBudget = false;
    VisualizationRecord? latest;
    final items = <String, VisualizationItem>{};
    var count = 0;
    while (count < maximumRecordsPerPass &&
        (count == 0 || _now() - started < maximumPassDuration)) {
      final bytes = tryAcquire();
      if (bytes == null) break;
      late final VisualizationRecord record;
      try {
        record = decodeVisualizationRecord(bytes);
        recordsRead++;
        bytesRead += bytes.length;
      } finally {
        release();
      }
      count++;
      if (_generation != null && record.generation < _generation!) {
        skippedRecords++;
        continue;
      }
      if (_generation != null && record.generation != _generation) {
        items.clear();
        reset = true;
      }
      if (_sequence != null &&
          record.sequence != ((_sequence! + 1) & 0xffffffff)) {
        reset = true;
      }
      _generation = record.generation;
      _sequence = record.sequence;
      if (_lastRecordTime != null &&
          started - _lastRecordTime! > visualizationHistoryDuration) {
        reset = true;
      }
      _lastRecordTime = started;
      latest = record;
      for (final item in record.update.items) {
        final previous = items[item.id];
        if (previous == null ||
            previous.valueType != item.valueType ||
            (previous.sampleTimestamps.isNotEmpty &&
                item.sampleTimestamps.isNotEmpty &&
                item.sampleTimestamps.first < previous.sampleTimestamps.last)) {
          items[item.id] = item;
        } else {
          (previous.values as List).addAll(item.values as List);
          previous.sampleTimestamps.addAll(item.sampleTimestamps);
        }
      }
      final cutoff =
          record.newestSampleTimestamp -
          (record.sampleRate *
                  visualizationHistoryDuration.inMilliseconds /
                  1000)
              .round();
      for (final item in items.values) {
        final timestamps = item.sampleTimestamps;
        var discard = 0;
        // Keep the last value even for slowly changing integer streams.
        while (discard + 1 < timestamps.length &&
            timestamps[discard] < cutoff) {
          discard++;
        }
        if (discard > 0) {
          timestamps.removeRange(0, discard);
          (item.values as List).removeRange(0, discard);
          skippedSamples += discard;
        }
      }
    }
    reachedBudget =
        count == maximumRecordsPerPass ||
        _now() - started >= maximumPassDuration;
    final elapsed = (_now() - started).inMicroseconds;
    if (elapsed > maximumDrainMicroseconds) maximumDrainMicroseconds = elapsed;
    if (latest == null) return;
    if (reset) discontinuities++;
    onRecord(
      VisualizationRecord(
        sequence: latest.sequence,
        generation: latest.generation,
        sampleRate: latest.sampleRate,
        newestSampleTimestamp: latest.newestSampleTimestamp,
        update: VisualizationUpdateEvent(id: -1, items: items.values.toList()),
        discontinuity: reset,
      ),
    );
  }
}
