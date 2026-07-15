# First steps

Anthem is an open-source DAW. It is written in Dart and C++, using Flutter and JUCE.

- Read [the overview docs page](docs/README.md) for an overview of the project architecture.
- Check for a `.dart_tool/` folder in the root of the repository. If it does not exist, you may prompt the user to ensure they have the required prerequisites, then follow the instructions in the relevant setup file in `docs/`. Note that the web setup file is relevant for all platforms.
- Read ./.github/workflows/build.yaml, which contains many useful commands for working with the repo, and examples for running all the tests.

# Repository setup and project-specific commands

- `dart run :cli codegen generate` to generate code. Prefer adding `--root-only` unless running for the first time, if it is not necessary to re-generate model files for the tests in `codegen/` (which is most of the time).
- When building the engine, CI uses the `--release` flag. Prefer `--debug` to `--release` during development.

# Verification

- For Dart changes, run relevant tests, run analysis, and format code.
- For engine changes, run engine unit tests when applicable, and format C++ code. Do not run engine linting unless the engineer explicitly asks for it; when engine linting would be useful, suggest it as a follow-up step.

## Dart verification commands

- Format Dart code: `dart format .`
- Check Dart formatting the way CI does: `dart format . --set-exit-if-changed -o none`
- Run Dart analysis on PowerShell: `New-Item -ItemType Directory -Force assets/engine | Out-Null; dart analyze --fatal-infos`
- Run Dart analysis the way CI does on Bash: `mkdir -p assets/engine && dart analyze --fatal-infos`
- Run a relevant Flutter test file or folder: `flutter test test/path/to_test.dart`
- Run the root package and codegen Flutter tests: `flutter test test codegen/test`
- Run analyzer plugin tests: run `dart test` from `tools/anthem_analyzer_plugin/`
- Run the full Dart test command from CI: `dart run anthem:cli flutter_test`

## Engine verification commands

- Format Anthem-owned engine C++ files: `dart run anthem:cli engine format`
- Check engine C++ formatting the way CI does: `dart run anthem:cli engine format --check`
- Run engine unit tests: `dart run anthem:cli engine unit-test`
- Run engine unit tests with Clang on Windows when needed: `dart run anthem:cli engine unit-test --clang`
- Build the engine for local development: `dart run anthem:cli engine build --debug`
- Build the engine the way CI does: `dart run anthem:cli engine build --release`
- Build the WebAssembly engine the way CI does: `dart run anthem:cli engine build --release --wasm`
- Run engine linting only when explicitly asked: `dart run anthem:cli engine lint`
- Run engine linting without refreshing CMake configuration only when explicitly asked and the lint build directory is already configured: `dart run anthem:cli engine lint --skip-configuration`

## Flutter build verification commands

- Build Linux the way CI does: `flutter build linux --verbose --release`
- Build macOS the way CI does: `flutter build macos --verbose --release`
- Build Windows the way CI does: `flutter build windows --verbose --release`
- Build web the way CI does: `flutter build web --verbose --release --wasm`
- Build the Windows installer the way CI does: `iscc /DMyArch=<x64|arm64> packaging/windows/anthem.iss`

# Development best practices

- Update the copyright year in headers when making changes.
- In C++, when writing real-time-safe code, use `rt_` to prefix all fields and methods that are only valid when accessed on the audio thread. For example, `rt_myMethod()` and `rt_myField()`, not `rtMyMethod()` or `rtMyField`.

# Directives

- Do not read anything from `docs/design/` unless specifically asked to, as they are not relevant to day-to-day coding tasks.
- Read files from `docs/architecture/` that seem relevant to your task.
- Project file changes may need a migration associated with them. Some notes about this:
  - The "current version" of the software should always be an upcoming version. You shouldn't need to bump the software version before adding a migration; you can target the current version as reported in `lib/version.dart`.
  - Migrations should be tested thoroughly.
