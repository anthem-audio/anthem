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

import 'dart:async';
import 'dart:js_interop';

import 'package:archive/archive.dart';
import 'package:web/web.dart' as web;

import '../archive_extraction.dart';
import '../archive_format.dart';
import '../errors.dart';
import 'archive_worker_message.dart';
import 'archive_worker_source.dart';

/// Supplies browser ZIP entries to the shared Dart extraction workflow.
/// The worker handles range reads and decompression; all writes happen here
/// through the workflow's output stream, before acknowledging each chunk.
class ArchiveWorkerClient implements ProjectArchiveSource {
  final web.Worker _worker;
  final String _workerUrl;
  final String _archiveUrl;
  final int _length;
  Completer<ArchiveWorkerMessage>? _pending;
  OutputStream? _output;
  AsyncError? _failure;

  ArchiveWorkerClient._(
    this._worker,
    this._workerUrl,
    this._archiveUrl,
    this._length,
  ) {
    _worker.onmessage = ((web.MessageEvent event) {
      final pending = _pending;
      if (pending == null || pending.isCompleted) return;
      final message = event.data as ArchiveWorkerMessage;
      switch (message.operation) {
        case 'data':
          try {
            _output!.writeBytes(message.bytes!.toDart);
            _worker.postMessage(ArchiveWorkerMessage(operation: 'ack'));
          } catch (error, stack) {
            _worker.postMessage(
              ArchiveWorkerMessage(operation: 'ack', error: error.toString()),
            );
            _fail(error, stack);
          }
        case 'error':
          final cause = StateError(message.error!);
          final stack = StackTrace.fromString(message.stack ?? '');
          _fail(
            message.readError == true
                ? ProjectFileReadException(cause: cause, causeStackTrace: stack)
                : cause,
            stack,
          );
        default:
          pending.complete(message);
      }
    }).toJS;
    _worker.onerror = ((web.Event event) {
      _fail(StateError('Project archive worker failed.'));
    }).toJS;
    _worker.onmessageerror = ((web.MessageEvent event) {
      _fail(StateError('Cannot receive project archive data.'));
    }).toJS;
  }

  static Future<ArchiveWorkerClient> open(String archiveUrl, int length) async {
    final script = await loadArchiveWorkerSource();
    final url = web.URL.createObjectURL(web.Blob([script.toJS].toJS));
    try {
      return ArchiveWorkerClient._(
        web.Worker(url.toJS),
        url,
        archiveUrl,
        length,
      );
    } catch (_) {
      web.URL.revokeObjectURL(url);
      rethrow;
    }
  }

  void _fail(Object error, [StackTrace? stack]) {
    final failure = _failure ??= AsyncError(error, stack);
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(failure.error, failure.stackTrace);
    }
  }

  Future<ArchiveWorkerMessage> _request(ArchiveWorkerMessage message) async {
    assert(_pending == null);
    final failure = _failure;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    final pending = _pending = Completer<ArchiveWorkerMessage>();
    try {
      _worker.postMessage(message);
      return await pending.future;
    } finally {
      _pending = null;
    }
  }

  @override
  Future<List<ProjectArchiveEntry>> readEntries() async {
    final reply = await _request(
      ArchiveWorkerMessage(
        operation: 'open',
        path: _archiveUrl,
        length: _length,
      ),
    );
    return [
      for (final entry in reply.entries.toDart)
        (
          name: entry.name,
          isDirectory: entry.isDirectory,
          isSymbolicLink: entry.isSymbolicLink,
          length: entry.length,
          crc32: entry.crc32,
        ),
    ];
  }

  @override
  Future<void> writeFile(int entryIndex, OutputStream output) async {
    _output = output;
    try {
      await _request(
        ArchiveWorkerMessage(operation: 'file', index: entryIndex),
      );
    } finally {
      _output = null;
    }
  }

  @override
  Future<void> close() async {
    _worker.terminate();
    web.URL.revokeObjectURL(_workerUrl);
  }
}
