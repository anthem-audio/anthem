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

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:anthem_native_ipc/anthem_native_ipc.dart';
import 'package:test/test.dart';

void main() {
  test('records survive cursor rollover and fill the maximum record size', () {
    final region = SharedMemoryRegion.create(288);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    final writer = SharedMemoryRecordRingBufferWriter.open(region);
    addTearDown(region.close);
    addTearDown(reader.close);
    addTearDown(writer.close);
    final bytes = ByteData.sublistView(region.bytes);
    bytes.setUint32(0, 0xffffffe8, Endian.host);
    bytes.setUint32(64, 0xffffffe8, Endian.host);
    final first = Uint8List(20)..fillRange(0, 20, 7);
    final second = Uint8List(8)..fillRange(0, 8, 9);
    expect(writer.tryWrite(first), isTrue);
    expect(writer.tryWrite(second), isTrue);
    expect(reader.tryAcquire(), orderedEquals(first));
    reader.release();
    expect(reader.tryAcquire(), orderedEquals(second));
    reader.release();
    final maximum = Uint8List(60);
    expect(writer.tryWrite(maximum), isTrue);
    expect(reader.tryAcquire(), orderedEquals(maximum));
    reader.release();
  });

  test('closing a held reader releases its record', () {
    final region = SharedMemoryRegion.create(256);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    final writer = SharedMemoryRecordRingBufferWriter.open(region);
    addTearDown(region.close);
    addTearDown(writer.close);
    expect(writer.tryWrite(Uint8List.fromList([7])), isTrue);
    expect(reader.tryAcquire(), orderedEquals([7]));
    reader.close();
    final nextReader = SharedMemoryRecordRingBufferReader.open(region);
    addTearDown(nextReader.close);
    expect(nextReader.tryAcquire(), isNull);
  });

  test('endpoints can close after their mapping is explicitly closed', () {
    final region = SharedMemoryRegion.create(256);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    final writer = SharedMemoryRecordRingBufferWriter.open(region);
    writer.tryWrite(Uint8List(1));
    reader.tryAcquire();
    region.close();
    expect(reader.tryAcquire, throwsStateError);
    reader.close();
    writer.close();
  });

  test('records are acquired in order and remain held until release', () {
    final region = SharedMemoryRegion.create(256);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    final writer = SharedMemoryRecordRingBufferWriter.open(region);
    addTearDown(region.close);
    addTearDown(reader.close);
    addTearDown(writer.close);

    expect(reader.tryAcquire(), isNull);
    expect(writer.tryWrite(Uint8List.fromList([1, 2, 3])), isTrue);
    expect(writer.tryWrite(Uint8List.fromList([4, 5])), isTrue);

    final first = reader.tryAcquire();
    expect(first, orderedEquals([1, 2, 3]));
    expect(reader.tryAcquire, throwsStateError);
    reader.release();

    final second = reader.tryAcquire();
    expect(second, orderedEquals([4, 5]));
    reader.release();
    expect(reader.tryAcquire(), isNull);
    expect(reader.release, throwsStateError);
  });

  test('records wrap and a full ring rejects the whole new record', () {
    final region = SharedMemoryRegion.create(256);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    final writer = SharedMemoryRecordRingBufferWriter.open(region);
    addTearDown(region.close);
    addTearDown(reader.close);
    addTearDown(writer.close);

    final smallRecord = Uint8List(20)..fillRange(0, 20, 7);
    for (var index = 0; index < 5; index++) {
      expect(writer.tryWrite(smallRecord), isTrue);
    }
    expect(writer.tryWrite(smallRecord), isFalse);

    for (var index = 0; index < 3; index++) {
      expect(reader.tryAcquire(), orderedEquals(smallRecord));
      reader.release();
    }

    final wrappedRecord = Uint8List(36)..fillRange(0, 36, 9);
    expect(writer.tryWrite(wrappedRecord), isTrue);

    for (var index = 0; index < 2; index++) {
      expect(reader.tryAcquire(), orderedEquals(smallRecord));
      reader.release();
    }
    expect(reader.tryAcquire(), orderedEquals(wrappedRecord));
    reader.release();
    expect(reader.tryAcquire(), isNull);
  });

  test('zero-length records are supported', () {
    final region = SharedMemoryRegion.create(256);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    final writer = SharedMemoryRecordRingBufferWriter.open(region);
    addTearDown(region.close);
    addTearDown(reader.close);
    addTearDown(writer.close);

    expect(writer.tryWrite(Uint8List(0)), isTrue);
    expect(reader.tryAcquire(), isEmpty);
    reader.release();
    expect(reader.tryAcquire(), isNull);
  });

  test('oversized records are rejected as errors', () {
    final region = SharedMemoryRegion.create(256);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    final writer = SharedMemoryRecordRingBufferWriter.open(region);
    addTearDown(region.close);
    addTearDown(reader.close);
    addTearDown(writer.close);

    expect(
      () => writer.tryWrite(Uint8List(61)),
      throwsA(isA<RecordRingBufferException>()),
    );
    expect(reader.tryAcquire(), isNull);
  });

  test('a child process can publish a record', () async {
    final region = SharedMemoryRegion.create(4096);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    addTearDown(region.close);
    addTearDown(reader.close);

    final libraryUri = await Isolate.resolvePackageUri(
      Uri.parse('package:anthem_native_ipc/anthem_native_ipc.dart'),
    );
    if (libraryUri == null) {
      fail('Could not resolve the anthem_native_ipc package directory.');
    }

    final packageDirectory = File.fromUri(libraryUri).parent.parent;
    final repositoryDirectory = packageDirectory.parent.parent;
    final childScript = packageDirectory.uri
        .resolve('test/helpers/record_ring_buffer_child.dart')
        .toFilePath();

    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      childScript,
      region.identifier,
      region.size.toString(),
    ], workingDirectory: repositoryDirectory.path);

    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    expect(reader.tryAcquire(), orderedEquals([11, 22, 33, 44]));
    reader.release();
  });

  test('invalid regions and closed endpoints are rejected', () {
    final smallRegion = SharedMemoryRegion.create(128);
    addTearDown(smallRegion.close);
    expect(
      () => SharedMemoryRecordRingBufferReader.initialize(smallRegion),
      throwsA(isA<RecordRingBufferException>()),
    );

    final region = SharedMemoryRegion.create(256);
    final reader = SharedMemoryRecordRingBufferReader.initialize(region);
    final writer = SharedMemoryRecordRingBufferWriter.open(region);
    addTearDown(region.close);

    reader.close();
    reader.close();
    writer.close();
    writer.close();

    expect(reader.tryAcquire, throwsStateError);
    expect(() => writer.tryWrite(Uint8List(1)), throwsStateError);
  });
}
