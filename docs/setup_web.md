## Setup for Web Development

Web development has been tested on Windows and Linux, but not macOS. It likely works on macOS, possibly with a few tweaks to the Dart build scripts.

### Prerequisites

Follow the setup instructions for your platform:

- [Windows](./setup_windows.md)
- [macOS](./setup_macos.md)
- [Linux](./setup_linux.md)

After this, install Emscripten. On Windows, install it under WSL2; the development scripts expect this, and will use Emscripten under WSL2 to build the engine when using the `--wasm` flag. See below for instructions.

### Instructions

1. Make sure you've built once on your native platform, or at least run codegen once.
2. Run `dart run anthem:cli engine build --debug --wasm` to build the engine.
3. Run `dart run anthem:cli flutter_run_web_with_proxy`. This will start a reverse proxy to insert request headers necessary for the engine to run correctly during development. See: https://developer.mozilla.org/en-US/docs/Web/API/Window/crossOriginIsolated
