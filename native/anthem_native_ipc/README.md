# Anthem native IPC

This package contains the native IPC primitives shared by Anthem's Flutter UI
and audio engine.

The native implementation is exposed to Dart through a C ABI and can also be
consumed directly from C++ through the provided CMake target. Platform details
are kept behind the `SharedMemoryRegion` abstraction. The package also provides
a non-blocking SPSC record ring that stores complete variable-length records in
shared memory.

The ring uses the largest power-of-two data capacity fitting after 128 bytes of
cursor storage. This preserves record positions when the 32-bit cursors wrap.
The writer publishes complete records or returns false; the reader acquires a
contiguous view which remains valid until release. Close endpoints before closing
their mapping. `availableBytes` includes record headers and wrap padding and can
be used to inspect queue pressure.

Run `dart test` from this package to test the native primitives. The two
cross-process tests use `dart build cli` to build their helpers into separate
temporary bundles, then launch the resulting executables. Each bundle has its
own native library, so the children can run concurrently without replacing the
library loaded by the parent test process. The bundles are removed after the
children exit.
