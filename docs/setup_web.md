## Setup for Web Development

Web development has been tested on Windows and Linux, but not macOS. It likely works on macOS, possibly with a few tweaks to the Dart build scripts.

### Prerequisites

Follow the setup instructions for your platform:

- [Windows](./setup_windows.md)
- [macOS](./setup_macos.md)
- [Linux](./setup_linux.md)

After this, install Emscripten 6.0.13 or newer. The AudioWorklet backend requires mixed pthread/Wasm Worker support. On Windows, install it under WSL2; the development scripts expect this, and will use Emscripten under WSL2 to build the engine when using the `--wasm` flag. See below for instructions.

### Instructions

1. Make sure you've built once on your native platform, or at least run codegen once.
2. Run `dart run anthem:cli engine build --debug --wasm` to build the engine.
3. Run `dart run anthem:cli flutter_run_web_with_proxy`. This runs Flutter with WebAssembly behind the proxy that supplies the COOP/COEP headers needed by the engine's shared memory. Use `--no-wasm` to run the Flutter UI with JavaScript instead.

If you want to test against non-Chromium browsers, or if you want to test a production build in any browser, you will need to create a production web build for the main Flutter application, and then run it behind a proxy that inserts response headers that are necessary for the engine to run correctly.

You can do this with the following steps:

1. Make sure the engine is built using the steps above.
2. Run `flutter build web --wasm`.
3. Run `dart run anthem:cli flutter_run_web_with_proxy --serve-existing-build`.

### Experimental Rust engine

Install Rust with rustup in the same environment as Emscripten. On Windows,
install Rust inside WSL2 and make sure `cargo` and `emcc` are on the login
shell's `PATH`. From the repository root, install the pinned nightly and the
Rust standard library sources that the threaded Emscripten build recompiles.

```sh
bash engine-rust/build-web.sh --install-toolchain
```

Build the Rust web engine with the Anthem CLI.

```sh
dart run anthem:cli codegen generate --root-only
dart run anthem:cli engine build --backend rust --debug --wasm
```

The CLI stages the artifacts in `build/rust-web/debug` or `build/rust-web/release`
and copies the module into `web/engine`, where Flutter loads it. Building an
engine selects that build for subsequent Flutter runs.

Run the Dart-to-engine runtime scenarios in headless Chrome with:

```sh
dart run anthem:cli engine runtime-test --wasm
```

This builds the Rust engine, then runs the same project-sync and asynchronous
request scenarios with Dart compiled to JavaScript and WebAssembly. Use
`--skip-build` to reuse an engine build, `--release` for a release engine, or
`--compiler js` / `--compiler wasm` to select one Dart compiler. The test server
provides the cross-origin isolation headers needed by shared memory. Chrome
must be installed; `CHROME_EXECUTABLE` can select its location.

### Audio processing

The engine's control threads and its AudioWorklet share WebAssembly memory. The
worklet invokes the existing C++ audio callback directly, using the AudioContext's
sample rate and render quantum. It reuses the context when audio is stopped and
started, and keeps its stack alive for the lifetime of the engine module.

Use JUCE's platform timing functions in audio-thread code. In an AudioWorklet,
`std::chrono::steady_clock` (also used by `high_resolution_clock` in this
toolchain) requests an unavailable monotonic clock and can abort. Emscripten's
clock used by the JUCE web port falls back to `Date.now()` where
`performance.now()` is unavailable, so web CPU-burden measurements have coarser
resolution than native measurements.
