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

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:anthem/engine_api/wasm_visualization_record_ring_buffer.dart';
import 'package:anthem/engine_api/visualization_record.dart';
import 'package:test/test.dart';

import '../../fixtures/visualization_record_fixture.dart';

void main() {
  test(
    'binary values decode from a JavaScript heap into owned Dart values',
    () {
      final bytes = visualizationRecordFixture();
      final heap = bytes.toJS;
      final record = decodeVisualizationRecord(heap.toDart);
      expect(record.generation, 9);
      expect(record.newestSampleTimestamp, 20);
      expect(record.update.items[0].values, [-0.0, 1.5]);
      expect(record.update.items[1].values, [-7, 9007199254740991]);
      expect(record.update.items.map((item) => item.id), ['d-Ω', 'i']);
      heap.setProperty('52'.toJS, 0.toJS);
      expect(record.update.items.first.id, 'd-Ω');
      if (identical(1, 1.0)) {
        final data = ByteData.sublistView(heap.toDart);
        data.setUint32(12, 0, Endian.little);
        data.setUint32(16, 0x200000, Endian.little);
        expect(
          () => decodeVisualizationRecord(heap.toDart),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'WASM reader reacquires the current heap and holds views until release',
    () {
      final app = JSObject();
      var heap = Uint8List(32).toJS;
      var size = 3;
      var releases = 0;
      app.setProperty('HEAPU8'.toJS, heap);
      app.setProperty(
        '_tryAcquireVisualizationRecord'.toJS,
        (() => 1.toJS).toJS,
      );
      app.setProperty(
        '_getAcquiredVisualizationRecordData'.toJS,
        (() => 8.toJS).toJS,
      );
      app.setProperty(
        '_getAcquiredVisualizationRecordSize'.toJS,
        (() => size.toJS).toJS,
      );
      app.setProperty(
        '_getVisualizationRecordAvailableBytes'.toJS,
        (() => (size + 4).toJS).toJS,
      );
      app.setProperty(
        '_releaseVisualizationRecord'.toJS,
        (() {
          releases++;
          return 1.toJS;
        }).toJS,
      );
      heap.setProperty('8'.toJS, 7.toJS);
      final reader = WasmVisualizationRecordRingBufferReader(app);
      final first = reader.tryAcquire()!;
      expect(first, [7, 0, 0]);
      heap.setProperty('8'.toJS, 9.toJS);
      expect(first.first, 9);
      expect(reader.tryAcquire, throwsStateError);
      reader.release();
      expect(releases, 1);

      // Simulate WebAssembly memory growth replacing Emscripten's heap view.
      heap = Uint8List(64).toJS;
      heap.setProperty('8'.toJS, 11.toJS);
      app.setProperty('HEAPU8'.toJS, heap);
      expect(reader.tryAcquire(), [11, 0, 0]);
      reader.release();
      expect(reader.availableBytes, 7);

      size = 1000;
      expect(reader.tryAcquire, throwsStateError);
      expect(
        releases,
        3,
        reason: 'An invalid view must release the native record.',
      );
      size = 3;
      reader.tryAcquire();
      reader.close();
      expect(releases, 4);
      expect(reader.tryAcquire, throwsStateError);
      reader.close();
      expect(releases, 4);
    },
  );
}
