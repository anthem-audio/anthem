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

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_bindings.dart' as bindings;

const _maximumSupportedSize = 0x7FFFFFFFFFFFFFFF;

/// An error reported while creating or opening a shared memory region.
final class SharedMemoryException implements Exception {
  final String message;

  const SharedMemoryException(this.message);

  @override
  String toString() => 'SharedMemoryException: $message';
}

/// Owns this process's mapping of a shared memory region.
///
/// Call [close] when the mapping is no longer needed. The [bytes] view becomes
/// invalid when the region is closed, including views retained by callers.
final class SharedMemoryRegion implements Finalizable {
  static final _finalizer = NativeFinalizer(
    Native.addressOf(bindings.anthemSharedMemoryRegionDestroy),
  );
  static final _byteViewOwners = Expando<SharedMemoryRegion>();

  Pointer<Void> _handle;
  Uint8List? _bytes;

  final String identifier;
  final int size;

  SharedMemoryRegion._(this._handle, this.identifier, this.size) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Creates a zero-initialized shared memory region.
  factory SharedMemoryRegion.create(int size) {
    _validateSize(size);
    final handle = bindings.anthemSharedMemoryRegionCreate(size);
    return _fromNativeHandle(handle);
  }

  /// Opens a shared memory region created by another owner.
  factory SharedMemoryRegion.open({
    required String identifier,
    required int size,
  }) {
    if (identifier.isEmpty) {
      throw ArgumentError.value(identifier, 'identifier', 'Must not be empty.');
    }
    if (identifier.contains('\u0000')) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Must not contain null characters.',
      );
    }

    _validateSize(size);
    final nativeIdentifier = identifier.toNativeUtf8();

    try {
      final handle = bindings.anthemSharedMemoryRegionOpen(
        nativeIdentifier.cast(),
        size,
      );
      return _fromNativeHandle(handle);
    } finally {
      malloc.free(nativeIdentifier);
    }
  }

  /// The mapped bytes at this process's virtual address.
  Uint8List get bytes {
    _ensureOpen();
    final existingView = _bytes;
    if (existingView != null) {
      return existingView;
    }

    final view = bindings
        .anthemSharedMemoryRegionGetData(_handle)
        .asTypedList(size);

    // Keep the mapping owner alive if a caller retains only the byte view.
    _byteViewOwners[view] = this;
    _bytes = view;
    return view;
  }

  bool get isClosed => _handle == nullptr;

  /// Removes the identifier used to open this region where supported.
  ///
  /// Existing mappings remain valid. This unlinks the object on POSIX systems;
  /// Windows removes the name automatically after the last handle closes.
  void removeIdentifier() {
    _ensureOpen();
    if (bindings.anthemSharedMemoryRegionRemoveIdentifier(_handle) == 0) {
      throw SharedMemoryException(_lastNativeError());
    }
  }

  /// Releases this process's mapping. This method is idempotent.
  void close() {
    if (isClosed) {
      return;
    }

    _finalizer.detach(this);
    bindings.anthemSharedMemoryRegionDestroy(_handle);
    _handle = nullptr;
    _bytes = null;
  }

  static SharedMemoryRegion _fromNativeHandle(Pointer<Void> handle) {
    if (handle == nullptr) {
      throw SharedMemoryException(_lastNativeError());
    }

    final nativeIdentifier = bindings.anthemSharedMemoryRegionGetIdentifier(
      handle,
    );
    final size = bindings.anthemSharedMemoryRegionGetSize(handle);

    if (nativeIdentifier == nullptr || size == 0) {
      bindings.anthemSharedMemoryRegionDestroy(handle);
      throw const SharedMemoryException(
        'The native shared memory region returned invalid metadata.',
      );
    }

    return SharedMemoryRegion._(
      handle,
      nativeIdentifier.cast<Utf8>().toDartString(),
      size,
    );
  }

  static String _lastNativeError() {
    final error = bindings.anthemNativeIpcGetLastError();
    if (error == nullptr) {
      return 'Unknown native shared memory error.';
    }

    final message = error.cast<Utf8>().toDartString();
    return message.isEmpty ? 'Unknown native shared memory error.' : message;
  }

  static void _validateSize(int size) {
    RangeError.checkValueInInterval(size, 1, _maximumSupportedSize, 'size');
  }

  void _ensureOpen() {
    if (isClosed) {
      throw StateError('The shared memory region has been closed.');
    }
  }
}
