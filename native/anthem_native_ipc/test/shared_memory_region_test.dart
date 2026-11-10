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

import 'package:anthem_native_ipc/anthem_native_ipc.dart';
import 'package:test/test.dart';

void main() {
  // Include the engine's ring size: 16 MiB of records plus 128 bytes of cursors.
  for (final size in [1, 4096, 4097, (1 << 24) + 128]) {
    test('two mappings expose exactly $size shared bytes', () {
      final creator = SharedMemoryRegion.create(size);
      addTearDown(creator.close);
      final opener = SharedMemoryRegion.open(
        identifier: creator.identifier,
        size: size,
      );
      addTearDown(opener.close);

      expect(creator.size, size);
      expect(creator.bytes, hasLength(size));
      expect(opener.size, size);
      expect(opener.bytes, hasLength(size));
      expect(opener.bytes.first, 0);
      expect(opener.bytes.last, 0);

      creator.bytes[0] = 123;
      expect(opener.bytes.first, 123);

      opener.bytes[size - 1] = 45;
      expect(creator.bytes.last, 45);
    });
  }

  test('a smaller view exposes only the requested prefix', () {
    final creator = SharedMemoryRegion.create(4097);
    addTearDown(creator.close);
    final prefix = SharedMemoryRegion.open(
      identifier: creator.identifier,
      size: 17,
    );
    addTearDown(prefix.close);

    expect(prefix.size, 17);
    expect(prefix.bytes, hasLength(17));
    prefix.bytes[16] = 73;
    expect(creator.bytes[16], 73);
    expect(() => prefix.bytes[17], throwsRangeError);
  });

  test('a child process can open and update a mapping', () async {
    final creator = SharedMemoryRegion.create(4097);
    addTearDown(creator.close);
    creator.bytes[0] = 37;

    final libraryUri = await Isolate.resolvePackageUri(
      Uri.parse('package:anthem_native_ipc/anthem_native_ipc.dart'),
    );
    if (libraryUri == null) {
      fail('Could not resolve the anthem_native_ipc package directory.');
    }

    final packageDirectory = File.fromUri(libraryUri).parent.parent;
    final repositoryDirectory = packageDirectory.parent.parent;
    final childScript = packageDirectory.uri
        .resolve('test/helpers/shared_memory_child.dart')
        .toFilePath();

    final result = await Process.run(
      Platform.resolvedExecutable,
      ['run', childScript, creator.identifier, creator.size.toString()],
      // Use the repository root so the child bundles its native asset into a
      // different directory from the library currently loaded by this test
      // process. Windows does not allow an in-use DLL to be replaced.
      workingDirectory: repositoryDirectory.path,
    );

    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    expect(creator.bytes.last, 91);
  });

  test('existing mappings remain valid after the identifier is removed', () {
    final creator = SharedMemoryRegion.create(4096);
    final opener = SharedMemoryRegion.open(
      identifier: creator.identifier,
      size: creator.size,
    );
    addTearDown(creator.close);
    addTearDown(opener.close);

    creator.removeIdentifier();
    creator.bytes[0] = 88;
    expect(opener.bytes[0], 88);

    if (!Platform.isWindows) {
      expect(
        () => SharedMemoryRegion.open(
          identifier: creator.identifier,
          size: creator.size,
        ),
        throwsA(isA<SharedMemoryException>()),
      );
    }
  });

  test('closing the final mapping removes the identifier', () {
    final creator = SharedMemoryRegion.create(4096);
    final identifier = creator.identifier;
    final size = creator.size;
    creator.close();

    expect(
      () => SharedMemoryRegion.open(identifier: identifier, size: size),
      throwsA(isA<SharedMemoryException>()),
    );
  });

  test('open rejects a view larger than the backing storage', () {
    final creator = SharedMemoryRegion.create(1 << 20);
    addTearDown(creator.close);

    expect(
      () => SharedMemoryRegion.open(
        identifier: creator.identifier,
        size: creator.size * 2,
      ),
      throwsA(isA<SharedMemoryException>()),
    );
  });

  test('invalid creation sizes are rejected', () {
    expect(() => SharedMemoryRegion.create(0), throwsRangeError);
    expect(() => SharedMemoryRegion.create(-1), throwsRangeError);
  });

  test('identifiers containing null characters are rejected', () {
    expect(
      () => SharedMemoryRegion.open(
        identifier: 'invalid\u0000identifier',
        size: 4096,
      ),
      throwsArgumentError,
    );
  });

  test('close is idempotent and prevents further access', () {
    final region = SharedMemoryRegion.create(4096);
    region.close();
    region.close();

    expect(region.isClosed, isTrue);
    expect(() => region.bytes, throwsStateError);
    expect(region.removeIdentifier, throwsStateError);
  });
}
