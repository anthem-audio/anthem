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

@Native<Pointer<Void> Function(Uint64)>(
  symbol: 'anthem_shared_memory_region_create',
)
external Pointer<Void> anthemSharedMemoryRegionCreate(int size);

@Native<Pointer<Void> Function(Pointer<Char>, Uint64)>(
  symbol: 'anthem_shared_memory_region_open',
)
external Pointer<Void> anthemSharedMemoryRegionOpen(
  Pointer<Char> identifier,
  int size,
);

@Native<Pointer<Uint8> Function(Pointer<Void>)>(
  symbol: 'anthem_shared_memory_region_get_data',
)
external Pointer<Uint8> anthemSharedMemoryRegionGetData(Pointer<Void> region);

@Native<Uint64 Function(Pointer<Void>)>(
  symbol: 'anthem_shared_memory_region_get_size',
)
external int anthemSharedMemoryRegionGetSize(Pointer<Void> region);

@Native<Pointer<Char> Function(Pointer<Void>)>(
  symbol: 'anthem_shared_memory_region_get_identifier',
)
external Pointer<Char> anthemSharedMemoryRegionGetIdentifier(
  Pointer<Void> region,
);

@Native<Int32 Function(Pointer<Void>)>(
  symbol: 'anthem_shared_memory_region_remove_identifier',
)
external int anthemSharedMemoryRegionRemoveIdentifier(Pointer<Void> region);

@Native<Void Function(Pointer<Void>)>(
  symbol: 'anthem_shared_memory_region_destroy',
)
external void anthemSharedMemoryRegionDestroy(Pointer<Void> region);

@Native<Pointer<Char> Function()>(symbol: 'anthem_native_ipc_get_last_error')
external Pointer<Char> anthemNativeIpcGetLastError();
