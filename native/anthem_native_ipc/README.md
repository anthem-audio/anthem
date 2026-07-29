# Anthem native IPC

This package contains the native IPC primitives shared by Anthem's Flutter UI
and audio engine.

The native implementation is exposed to Dart through a C ABI and can also be
consumed directly from C++ through the provided CMake target. Platform details
are kept behind the `SharedMemoryRegion` abstraction.
