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

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:anthem/logic/project_file/archive.dart';
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/web/archive_worker_message.dart';
import 'package:anthem/logic/project_file/web/archive_worker_source.dart';
import 'package:anthem/logic/storage/asset_file_io.dart' as files;
import 'package:anthem/logic/storage/browser_file_system.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:web/web.dart' as web;

import '../../../helpers/browser_engine_test_helpers.dart';
import '../../../helpers/browser_asset_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    useBrowserPackageAssets();
    await loadBrowserModule('AnthemFileSystem');
  });

  Future<Set<String>> roots() async {
    await files.createDirectory('/anthem/projects');
    return {
      for (final entry in await files.listEntries('/anthem/projects'))
        entry.name,
    };
  }

  test('worker reads bounded slices and waits for writes before sending more', () async {
    final random = Random(42);
    final content = Uint8List.fromList(
      List.generate(3 * archiveTransferSize + 19, (_) => random.nextInt(256)),
    );
    final bytes = ZipEncoder().encodeBytes(
      Archive()
        ..add(ArchiveFile.bytes('project.anthem', [1, 2, 3]))
        ..add(ArchiveFile.bytes('assets/compressed.bin', content))
        ..add(
          ArchiveFile.noCompress('assets/stored.bin', content.length, content),
        )
        ..add(ArchiveFile.bytes('assets/empty.bin', [])),
    );
    expect(bytes.length, greaterThan(archiveTransferSize));
    final script = await loadArchiveWorkerSource();
    // Enforce the read bound inside the real worker, including reads performed
    // by zip.js. No whole-file fetch may hide behind a successful round trip.
    final instrumented =
        """
self.Worker = class { constructor() { throw new Error('Unexpected nested worker'); } };
const originalFetch = self.fetch;
self.fetch = (url, options) => {
  const range = /^bytes=(\\d+)-(\\d+)\$/.exec(options?.headers?.Range || '');
  if (!range || Number(range[2]) - Number(range[1]) + 1 > $archiveTransferSize)
    throw new Error('Unbounded Blob read');
  return originalFetch(url, options);
};
$script
// Exercise the vendored JavaScript fallback as well as the browser's native
// decompression, which the other import tests use.
zip.configure({ useCompressionStream: false });
""";
    final workerUrl = web.URL.createObjectURL(
      web.Blob([instrumented.toJS].toJS),
    );
    final inputUrl = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
    final worker = web.Worker(workerUrl.toJS);
    final messages = StreamController<ArchiveWorkerMessage>();
    var received = 0;
    worker.onmessage = ((web.MessageEvent event) {
      received++;
      messages.add(event.data as ArchiveWorkerMessage);
    }).toJS;
    worker.onerror = ((web.Event event) {
      messages.addError(StateError('Archive test worker failed.'));
    }).toJS;
    final iterator = StreamIterator(messages.stream);
    try {
      worker.postMessage(
        ArchiveWorkerMessage(
          operation: 'open',
          path: inputUrl,
          length: bytes.length,
        ),
      );
      expect(await iterator.moveNext(), isTrue);
      final listing = iterator.current;
      if (listing.operation == 'error') fail(listing.error!);
      expect(listing.operation, 'entries');
      final entries = listing.entries.toDart;
      final extracted = <String, Uint8List>{};
      var chunks = 0;
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        if (entry.isDirectory) continue;
        final contents = BytesBuilder();
        worker.postMessage(
          ArchiveWorkerMessage(operation: 'file', index: index),
        );
        while (await iterator.moveNext()) {
          final message = iterator.current;
          if (message.operation == 'error') fail(message.error!);
          if (message.operation == 'done') break;
          expect(message.operation, 'data');
          final chunk = message.bytes!.toDart;
          expect(chunk.length, inInclusiveRange(1, archiveTransferSize));
          contents.add(chunk);
          if (chunks++ == 0) {
            final before = received;
            await Future<void>.delayed(const Duration(milliseconds: 30));
            expect(
              received,
              before,
              reason: 'Output must wait for acknowledgement.',
            );
          }
          worker.postMessage(ArchiveWorkerMessage(operation: 'ack'));
        }
        final output = contents.takeBytes();
        expect(output.length, entry.length);
        expect(getCrc32(output), entry.crc32);
        extracted[entry.name] = output;
      }
      expect(chunks, greaterThan(6));
      expect(extracted['project.anthem'], [1, 2, 3]);
      expect(extracted['assets/compressed.bin'], content);
      expect(extracted['assets/stored.bin'], content);
      expect(extracted['assets/empty.bin'], isEmpty);
    } finally {
      worker.terminate();
      await iterator.cancel();
      await messages.close();
      web.URL.revokeObjectURL(workerUrl);
      web.URL.revokeObjectURL(inputUrl);
    }
  });

  test(
    'browser decoder preserves unsafe entries for shared project validation',
    () async {
      final before = await roots();
      for (final entries in [
        <ArchiveFile>[],
        [
          ArchiveFile.bytes('folder/project.anthem', [1]),
        ],
        [
          ArchiveFile.bytes('a.anthem', [1]),
          ArchiveFile.bytes('b.anthem', [2]),
        ],
        [
          ArchiveFile.bytes('project.anthem', [1]),
          ArchiveFile.string('assets/link', '../../outside')..mode = 0xa1ff,
        ],
        [
          ArchiveFile.bytes('project.anthem', [1]),
          ArchiveFile.bytes('assets/a.bin', [1]),
          ArchiveFile.bytes('Assets/b.bin', [2]),
        ],
      ]) {
        final archive = Archive();
        entries.forEach(archive.add);
        await expectLater(
          extractProjectArchiveBytes(ZipEncoder().encodeBytes(archive)),
          throwsA(isA<InvalidProjectFileException>()),
        );
        expect(await roots(), before);
      }
      final archive = Archive()
        ..add(ArchiveFile.bytes('project.anthem', [1]))
        ..add(ArchiveFile.bytes('assets/a.bin', [2]))
        ..add(ArchiveFile.bytes('assets/b.bin', [3]));
      final duplicate = latin1.encode(
        latin1
            .decode(ZipEncoder().encodeBytes(archive))
            .replaceAll('assets/b.bin', 'assets/a.bin'),
      );
      await expectLater(
        extractProjectArchiveBytes(duplicate),
        throwsA(isA<InvalidProjectFileException>()),
      );
      expect(await roots(), before);
    },
  );

  test('filesystem write failure closes the file and removes partial extraction', () async {
    final before = await roots();
    final fs = (await BrowserFileSystem.instance).fs;
    final original = fs.getProperty<JSFunction>('write'.toJS);
    var writes = 0;
    fs.setProperty(
      'write'.toJS,
      ((JSObject stream, JSUint8Array data, JSNumber offset, JSNumber length) {
        writes++;
        // Report a short write to exercise failure after the file has opened.
        return 0.toJS;
      }).toJS,
    );
    try {
      final bytes = ZipEncoder().encodeBytes(
        Archive()..add(ArchiveFile.bytes('project.anthem', [1, 2, 3])),
      );
      await expectLater(
        extractProjectArchiveBytes(bytes),
        throwsA(isA<InvalidProjectFileException>()),
      );
      expect(writes, 1);
      expect(await roots(), before);
    } finally {
      fs.setProperty('write'.toJS, original);
    }
  });

  test('unreadable object URLs are reported as file read failures', () async {
    final before = await roots();
    final bytes = ZipEncoder().encodeBytes(
      Archive()..add(ArchiveFile.bytes('project.anthem', [1, 2, 3])),
    );
    final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
    web.URL.revokeObjectURL(url);
    await expectLater(
      extractProjectArchive(XFile(url, length: bytes.length)),
      throwsA(isA<ProjectFileReadException>()),
    );
    expect(await roots(), before);
  });
}
