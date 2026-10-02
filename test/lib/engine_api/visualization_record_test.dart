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

import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/engine_api/visualization_record.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List fixture() {
  final hex = File(
    'test/fixtures/visualization_record_v1.hex',
  ).readAsStringSync().trim();
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

Uint8List numericRecord(
  int sequence,
  List<int> timestamps,
  List<double> values, {
  int generation = 9,
}) {
  final bytes = Uint8List(53 + timestamps.length * 16);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 40, fixture().sublist(0, 40));
  data.setUint32(8, sequence, Endian.little);
  data.setUint64(12, generation, Endian.little);
  data.setInt64(28, timestamps.last, Endian.little);
  data.setUint32(36, 1, Endian.little);
  data.setUint32(40, 1, Endian.little);
  data.setUint32(44, 0, Endian.little);
  data.setUint32(48, timestamps.length, Endian.little);
  bytes[52] = 100;
  for (var i = 0; i < timestamps.length; i++) {
    data.setInt64(53 + i * 16, timestamps[i], Endian.little);
    data.setFloat64(61 + i * 16, values[i], Endian.little);
  }
  return bytes;
}

void main() {
  test(
    'C++ fixture decodes numeric values and UTF-8 IDs into owned Dart values',
    () {
      final bytes = fixture();
      final record = decodeVisualizationRecord(bytes);
      expect(record.sequence, 7);
      expect(record.generation, 9);
      expect(record.sampleRate, 48000);
      expect(record.newestSampleTimestamp, 20);
      expect(record.update.items.map((i) => i.id), ['d-Ω', 'i']);
      expect(
        record.update.items.map((i) => i.valueType),
        VisualizationValueType.values,
      );
      expect(record.update.items[0].values, [-0.0, 1.5]);
      expect(
        1 / (record.update.items[0].values as List<double>).first,
        double.negativeInfinity,
      );
      expect(record.update.items[1].values, [-7, 9007199254740991]);
      bytes.fillRange(0, bytes.length, 0);
      expect(record.update.items[0].sampleTimestamps, [10, 20]);
      expect(record.update.items[0].id, 'd-Ω');
      expect(record.update.items[1].values, [-7, 9007199254740991]);
    },
  );

  test('truncated records, unknown types and invalid lengths are rejected', () {
    final original = fixture();
    for (var length = 0; length < original.length; length++) {
      expect(
        () => decodeVisualizationRecord(
          Uint8List.sublistView(original, 0, length),
        ),
        throwsFormatException,
        reason: 'length $length',
      );
    }
    for (final offset in [0, 4, 36, 40, 44, 48]) {
      final bytes = fixture();
      ByteData.sublistView(bytes).setUint32(offset, 0xffffffff, Endian.little);
      expect(() => decodeVisualizationRecord(bytes), throwsFormatException);
    }
    final stringType = fixture();
    ByteData.sublistView(stringType).setUint32(44, 2, Endian.little);
    expect(() => decodeVisualizationRecord(stringType), throwsFormatException);
    final backwards = numericRecord(8, [20, 10], [1, 2]);
    expect(() => decodeVisualizationRecord(backwards), throwsFormatException);
    expect(
      () => decodeVisualizationRecord(Uint8List.fromList([...original, 0])),
      throwsFormatException,
    );
  });

  test('consumer releases malformed records before reporting an error', () {
    var releases = 0;
    final consumer = VisualizationRecordConsumer(
      tryAcquire: () => Uint8List(1),
      release: () => releases++,
      onRecord: (_) {},
    );
    expect(consumer.poll, throwsFormatException);
    expect(releases, 1);
  });

  test('bounded passes coalesce recent samples and preserve their peak', () {
    final queue = Queue<Uint8List>.from([
      numericRecord(1, [0, 4800], [9, 1]),
      numericRecord(2, [9600, 14400], [8, 2]),
      numericRecord(3, [24000], [3]),
    ]);
    final updates = <VisualizationRecord>[];
    var releases = 0;
    final consumer = VisualizationRecordConsumer(
      tryAcquire: () => queue.isEmpty ? null : queue.removeFirst(),
      release: () => releases++,
      onRecord: updates.add,
      now: () => Duration.zero,
      maximumRecordsPerPass: 2,
    );
    consumer.poll();
    expect(consumer.reachedBudget, isTrue);
    expect(releases, 2);
    expect(updates.single.update.items.single.values, [1.0, 8.0, 2.0]);
    expect(consumer.skippedSamples, 1);
    consumer.poll();
    expect(consumer.reachedBudget, isFalse);
    expect(releases, 3);
    expect(updates.last.update.items.single.values, [3.0]);
  });

  test('pauses, sequence gaps and session changes signal discontinuity', () {
    var now = Duration.zero;
    final queue = Queue<Uint8List>();
    final updates = <VisualizationRecord>[];
    final consumer = VisualizationRecordConsumer(
      tryAcquire: () => queue.isEmpty ? null : queue.removeFirst(),
      release: () {},
      onRecord: updates.add,
      now: () => now,
    );
    queue.add(numericRecord(1, [0], [1]));
    consumer.poll();
    expect(updates.last.discontinuity, isFalse);
    now = const Duration(seconds: 2);
    queue.add(numericRecord(2, [96000], [2]));
    consumer.poll();
    expect(updates.last.discontinuity, isTrue);
    queue.add(numericRecord(4, [97000], [3]));
    consumer.poll();
    expect(updates.last.discontinuity, isTrue);
    queue.add(numericRecord(5, [0], [4], generation: 10));
    consumer.poll();
    expect(updates.last.discontinuity, isTrue);
    queue.add(numericRecord(6, [98000], [5], generation: 9));
    consumer.poll();
    expect(updates, hasLength(4));
  });

  test('record sequence rollover is continuous', () {
    final queue = Queue<Uint8List>.from([
      numericRecord(0xffffffff, [0], [1]),
      numericRecord(0, [4800], [2]),
    ]);
    final updates = <VisualizationRecord>[];
    final consumer = VisualizationRecordConsumer(
      tryAcquire: () => queue.isEmpty ? null : queue.removeFirst(),
      release: () {},
      onRecord: updates.add,
      now: () => Duration.zero,
    );
    consumer.poll();
    expect(updates.single.discontinuity, isFalse);
    expect(updates.single.update.items.single.values, [1.0, 2.0]);
  });

  test('a large burst drains in bounded passes with recent peaks intact', () {
    final queue = Queue<Uint8List>.from([
      for (var i = 0; i < 1024; i++)
        numericRecord(i, [i * 48], [i == 900 ? 100 : i.toDouble() / 1024]),
    ]);
    final updates = <VisualizationRecord>[];
    var releases = 0;
    final consumer = VisualizationRecordConsumer(
      tryAcquire: () => queue.isEmpty ? null : queue.removeFirst(),
      release: () => releases++,
      onRecord: updates.add,
      now: () => Duration.zero,
      availableBytes: () => queue.length * 73,
    );
    while (queue.isNotEmpty) {
      final previousReleases = releases;
      consumer.poll();
      expect(releases - previousReleases, lessThanOrEqualTo(256));
    }
    expect(updates, hasLength(4));
    expect(consumer.recordsRead, 1024);
    expect(consumer.queueByteHighWater, 1024 * 73);
    expect(updates.last.update.items.single.values, contains(100.0));
    expect((updates.last.update.items.single.values as List).last, 1023 / 1024);
    for (final update in updates) {
      expect(
        update.update.items.single.sampleTimestamps.length,
        lessThanOrEqualTo(251),
      );
    }
  });
}
