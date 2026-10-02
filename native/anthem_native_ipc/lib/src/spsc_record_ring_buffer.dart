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

part of '../anthem_native_ipc.dart';

const _recordRingBufferError = -1;
const _recordRingBufferUnavailable = 0;
const _recordRingBufferSuccess = 1;

/// An error reported while initializing or using a shared record ring buffer.
final class RecordRingBufferException implements Exception {
  final String message;

  const RecordRingBufferException(this.message);

  @override
  String toString() => 'RecordRingBufferException: $message';
}

/// The non-blocking producer endpoint of a shared-memory SPSC record ring.
///
/// This Dart wrapper copies each record into temporary native memory. Anthem's
/// engine uses the C++ writer directly; this wrapper primarily supports tools
/// and cross-process verification.
final class SharedMemoryRecordRingBufferWriter implements Finalizable {
  static final _finalizer = NativeFinalizer(
    Native.addressOf(bindings.anthemSpscRecordRingBufferWriterDestroy),
  );

  final SharedMemoryRegion _region;
  Pointer<Void> _handle;

  SharedMemoryRecordRingBufferWriter._(this._region, this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  factory SharedMemoryRecordRingBufferWriter.open(SharedMemoryRegion region) {
    region._ensureOpen();
    final handle = bindings.anthemSpscRecordRingBufferWriterCreate(
      bindings.anthemSharedMemoryRegionGetData(region._handle),
      region.size,
    );
    if (handle == nullptr) {
      throw RecordRingBufferException(_nativeIpcLastError());
    }

    return SharedMemoryRecordRingBufferWriter._(region, handle);
  }

  /// Attempts to publish [record] as one unit. Returns false without
  /// publishing any part of it when the ring has insufficient free space.
  bool tryWrite(Uint8List record) {
    _ensureOpen();

    final nativeRecord = record.isEmpty
        ? nullptr
        : calloc<Uint8>(record.length);
    try {
      if (record.isNotEmpty) {
        nativeRecord.asTypedList(record.length).setAll(0, record);
      }

      final result = bindings.anthemSpscRecordRingBufferWriterTryWrite(
        _handle,
        nativeRecord,
        record.length,
      );
      if (result == _recordRingBufferSuccess) {
        return true;
      }
      if (result == _recordRingBufferUnavailable) {
        return false;
      }
      if (result == _recordRingBufferError) {
        throw RecordRingBufferException(_nativeIpcLastError());
      }
      throw RecordRingBufferException(
        'The native writer returned an unknown result: $result.',
      );
    } finally {
      if (nativeRecord != nullptr) {
        calloc.free(nativeRecord);
      }
    }
  }

  bool get isClosed => _handle == nullptr;

  void close() {
    if (isClosed) {
      return;
    }

    _finalizer.detach(this);
    bindings.anthemSpscRecordRingBufferWriterDestroy(_handle);
    _handle = nullptr;
  }

  void _ensureOpen() {
    if (isClosed) {
      throw StateError('The record ring buffer writer has been closed.');
    }
    _region._ensureOpen();
  }
}

/// The consumer endpoint of a shared-memory SPSC record ring.
///
/// [tryAcquire] returns a zero-copy view into shared memory. That view is valid
/// only until [release] or [close] is called. Exactly one acquired record may
/// be outstanding at a time.
final class SharedMemoryRecordRingBufferReader implements Finalizable {
  int get availableBytes {
    _ensureOpen();
    return bindings.anthemSpscRecordRingBufferReaderGetAvailableBytes(_handle);
  }

  static final _finalizer = NativeFinalizer(
    Native.addressOf(bindings.anthemSpscRecordRingBufferReaderDestroy),
  );
  static final _recordViewOwners =
      Expando<SharedMemoryRecordRingBufferReader>();

  final SharedMemoryRegion _region;
  Pointer<Void> _handle;
  bool _hasAcquiredRecord = false;

  SharedMemoryRecordRingBufferReader._(this._region, this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Initializes [region] and opens its reader endpoint. No other thread or
  /// process may access the region until this factory returns.
  factory SharedMemoryRecordRingBufferReader.initialize(
    SharedMemoryRegion region,
  ) {
    region._ensureOpen();
    final data = bindings.anthemSharedMemoryRegionGetData(region._handle);
    if (bindings.anthemSpscRecordRingBufferInitialize(data, region.size) == 0) {
      throw RecordRingBufferException(_nativeIpcLastError());
    }
    return SharedMemoryRecordRingBufferReader._open(region, data);
  }

  /// Opens the reader endpoint of an already initialized region.
  factory SharedMemoryRecordRingBufferReader.open(SharedMemoryRegion region) {
    region._ensureOpen();
    return SharedMemoryRecordRingBufferReader._open(
      region,
      bindings.anthemSharedMemoryRegionGetData(region._handle),
    );
  }

  static SharedMemoryRecordRingBufferReader _open(
    SharedMemoryRegion region,
    Pointer<Uint8> data,
  ) {
    final handle = bindings.anthemSpscRecordRingBufferReaderCreate(
      data,
      region.size,
    );
    if (handle == nullptr) {
      throw RecordRingBufferException(_nativeIpcLastError());
    }

    return SharedMemoryRecordRingBufferReader._(region, handle);
  }

  Uint8List? tryAcquire() {
    _ensureOpen();
    if (_hasAcquiredRecord) {
      throw StateError('Release the current record before acquiring another.');
    }

    final result = bindings.anthemSpscRecordRingBufferReaderTryAcquire(_handle);
    if (result == _recordRingBufferUnavailable) {
      return null;
    }
    if (result == _recordRingBufferError) {
      throw RecordRingBufferException(_nativeIpcLastError());
    }
    if (result != _recordRingBufferSuccess) {
      throw RecordRingBufferException(
        'The native reader returned an unknown result: $result.',
      );
    }

    final data = bindings.anthemSpscRecordRingBufferReaderGetData(_handle);
    final size = bindings.anthemSpscRecordRingBufferReaderGetSize(_handle);
    if (data == nullptr) {
      throw const RecordRingBufferException(
        'The native reader returned an invalid record pointer.',
      );
    }

    _hasAcquiredRecord = true;
    final record = data.asTypedList(size);
    _recordViewOwners[record] = this;
    return record;
  }

  void release() {
    _ensureOpen();
    if (!_hasAcquiredRecord) {
      throw StateError('No record is currently acquired.');
    }
    if (bindings.anthemSpscRecordRingBufferReaderRelease(_handle) == 0) {
      throw RecordRingBufferException(_nativeIpcLastError());
    }
    _hasAcquiredRecord = false;
  }

  bool get isClosed => _handle == nullptr;

  void close() {
    if (isClosed) {
      return;
    }

    if (_hasAcquiredRecord && !_region.isClosed) {
      bindings.anthemSpscRecordRingBufferReaderRelease(_handle);
    }
    _hasAcquiredRecord = false;
    _finalizer.detach(this);
    bindings.anthemSpscRecordRingBufferReaderDestroy(_handle);
    _handle = nullptr;
  }

  void _ensureOpen() {
    if (isClosed) {
      throw StateError('The record ring buffer reader has been closed.');
    }
    _region._ensureOpen();
  }
}
