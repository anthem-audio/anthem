# Desktop integration tests

The `integration_test/` suite runs the real Flutter desktop app, native plugins,
and an explicit Anthem engine executable. It is separate from
`flutter test test codegen/test` and the lower-level engine IPC tests.

After completing the platform setup guide, run:

```sh
dart run anthem:cli integration-test
```

Run code generation after model changes, as in the setup guide. The runner
builds the debug engine and chooses the host desktop device (`linux` or `macos`).
To use an engine you have already built:

```sh
dart run anthem:cli integration-test --engine /absolute/path/to/AnthemEngine
```

`--seed` shuffles scenario order for isolation checks; use a fixed integer to
reproduce a run. `--device` selects the host desktop explicitly. `--target`
selects a scenario file. `--output` selects an artifact directory; otherwise each run gets a new
`build/integration_test/` directory. The runner prints that path and returns the
Flutter test exit code. It never selects the bundled engine copy as a fallback.
Only one integration runner can own a checkout at a time, since Flutter desktop
targets share build output.

Linux requires a display; in a headless environment use:

```sh
xvfb-run -a -s "-screen 0 1280x800x24" dart run anthem:cli integration-test
```

## Current smoke coverage

`startup_test.dart` starts and closes two sessions in one app process, checks
initial model contents through engine IPC, and verifies fresh projects,
selection, undo history, overlays, dialogs, cursor state, settings, and keyboard
modifiers. It also covers a missing executable, a startup deadline with a child
that never connects, recovery after that failure, and readiness diagnostics.
Each shutdown awaits the actual child exit code rather than just sending a
signal. A shutdown that requires a forced kill is reported as a failure.

The harness initializes `IntegrationTestWidgetsFlutterBinding` before shared
application startup. Every session registers teardown before startup, uses
fresh in-memory preferences, and disables hardware audio. It renders the normal
app tree at 1280×800 logical pixels and checks actual arranger canvas bounds.
Logs and test files are written inside the run's artifact directory; user
project and settings locations are not used.

Readiness helpers pump frames and permit real IPC/timers while waiting for a
named condition with a deadline. They do not wait for global animation idleness.
`conditionDescription` labels the wait in timeout messages;
`collectTimeoutDiagnostics` runs only on timeout to add current debug details.
`AppTestSession.sessionDiagnostics` supplies session and engine details for
failure messages, and `writeSessionDiagnostics` saves them as JSON artifacts.
These diagnostics do not determine readiness or record a history of state.
Initial model acknowledgment establishes startup. Each model predicate queries
the engine again, with both a request and overall deadline. These observations
do not prove audio-thread adoption or audible output.

Artifacts currently include the runner transcript, Flutter version and engine
path, application/engine logs, session IDs/PIDs/exit codes, canvas bounds, and
engine model snapshots. Linux/Xvfb and macOS smoke jobs upload these even on
failure. Expanded diagnostics and additional editing/persistence scenarios are
later deliveries.

## Verify exception reporting

This explicit probe deliberately reports an uncaught Flutter framework error.
It must **fail** with a nonzero exit status while still shutting down its engine:

```sh
dart run anthem:cli integration-test --engine /absolute/path/to/AnthemEngine \
  --target integration_test/support/framework_error_probe.dart
```

The probe is outside automatic `*_test.dart` discovery. Normal app logging
chains the existing Flutter error handler so the integration binding continues
to report failures.
