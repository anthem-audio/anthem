# Testing

## Browser unit and widget tests

The same `flutter_test` command handles desktop and browser testing. `--web`
selects only the browser suites; without it, the command runs VM/host tests.

Run the portable Dart suites in Chrome with both JavaScript and WebAssembly:

```sh
dart run anthem:cli flutter_test --web
```

These suites cover math helpers, visualization buffering and binary decoding,
the WASM memory reader, length-prefixed JSON decoding, and codegen's writer.
They use `package:test` and run once with `dart2js` and once with `dart2wasm`.
Use `--compiler dart2js` or `--compiler dart2wasm` for a single compiler.

On Linux or macOS, include the existing Flutter unit and widget suites:

```sh
dart run anthem:cli flutter_test --web --widgets
```

The Flutter pass discovers tests under `test/lib` and `codegen/test`, excluding
the portable suites already run and the filesystem/build-tool suites listed in
[browser_test_suites.yaml](../test/browser_test_suites.yaml). New tests in these
directories are included automatically; add an exclusion only when a suite
requires desktop facilities. Tests that can run without Flutter can instead be
added to the manifest's `dart` list for coverage with both compilers.

The Flutter pass also runs with both JavaScript and WebAssembly by default.
`--compiler` selects the corresponding target for both passes: the standalone
JavaScript tests use `dart2js`, while Flutter's JavaScript runner uses DDC.
The [WASM compiler crash](https://github.com/dart-lang/sdk/issues/63904) that
previously blocked mocked test classes no longer reproduces with Dart 3.13.5.

Flutter's Chrome test backend is deprecated and intended for Flutter's own
tests. Its [Windows URL path bug](https://github.com/flutter/flutter/issues/192069)
still prevents the widget pass from running on Windows with Flutter 3.47.6;
the standalone Dart pass works on Windows. The CLI retains the Windows guard.
Native text-editing shortcut tests run on the VM because browsers handle those
shortcuts through the DOM; browser tests cover text-input and selection updates.

Chrome must be installed. Set `CHROME_EXECUTABLE` if the runner cannot find it.
Use `--list` (with `--widgets` to include Flutter suites) to inspect selection.
Console output defaults to `expanded`; `--reporter compact` and
`--reporter github` are also available. JSON event logs are written under
`.dart_tool/web-tests/`.

The web CI job runs `flutter_test --web --widgets` with both targets and uploads
the JSON logs, including when a test fails. Each Flutter package/target pair
has a separate JSON log. All selected tests execute in Chrome. This command
does not build or launch the complete app or engine and does not add integration
tests.

## Desktop and host tests

The existing command remains:

```sh
dart run anthem:cli flutter_test
```

It runs the root/codegen Flutter suites on the VM, plus the analyzer plugin and
native IPC package suites. This covers native shared-memory IPC, filesystem
operations, host build tools, and repository checks. The browser-only WASM
reader suite is skipped on the VM. Engine C++ tests run separately:

```sh
dart run anthem:cli engine unit-test
```

The web CI job does not run the desktop/host commands. Full app integration
testing is maintained separately.
