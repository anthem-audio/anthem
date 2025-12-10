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
3. Run `dart run --wasm -d chrome`.

If you want to test against non-Chromium browsers, or if you want to test a production build in any browser, you will need to create a production web build for the main Flutter application, and then run it behind a proxy that inserts response headers that are necessary for the engine to run correctly.

You can do this with the following steps:

1. Make sure the engine is built using the steps above.
2. Run `flutter build web --wasm`.
3. Run `dart run :anthem:cli flutter_run_web_with_proxy --serve-existing-build`.
