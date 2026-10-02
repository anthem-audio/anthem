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

The default target is the whole `integration_test/` suite. `--seed` shuffles
scenario order for isolation checks; use a fixed integer to reproduce a run.
`--device` selects the host desktop explicitly. `--target` selects a test file
or directory, for example `--target integration_test/note_editing_test.dart`.
Targets must be inside the package's `integration_test/` directory so Flutter
runs them with the real desktop app and native plugins.
`--output` selects an artifact directory; otherwise each run gets a new
`build/integration_test/` directory. The runner prints that path and returns the
Flutter test exit code. It never selects the bundled engine copy as a fallback.
Only one integration runner can own a checkout at a time, since Flutter desktop
targets share build output. The runner executes each test file in a separate
Flutter process, sequentially, so later files get a fresh desktop log reader.
It runs all selected files and returns the first failing exit code, if any.

Linux requires a display; in a headless environment use:

```sh
xvfb-run -a -s "-screen 0 1280x800x24" dart run anthem:cli integration-test
```

## Scenario coverage

`startup_test.dart` starts and closes two sessions in one app process, checks
initial model contents through engine IPC, and verifies fresh projects,
selection, undo history, overlays, dialogs, cursor state, settings, and keyboard
modifiers. It also covers a missing executable, a startup deadline with a child
that never connects, recovery after that failure, and readiness diagnostics.
Each shutdown awaits the actual child exit code rather than just sending a
signal. A shutdown that requires a forced kill is reported as a failure.

`note_editing_test.dart` draws a note through real mouse down/move/up events,
then uses the platform's primary modifier with Z for undo and Shift+Z for redo.
It checks the note's identity, pitch, offset, length, velocity, and pan in Dart
and in fresh engine model queries, plus its presence in rendered frame
annotations. It also checks offscreen target rejection, window resizing, and
modifier/pointer release after an input action fails.

`project_persistence_test.dart` creates an independently specified edited project
and calls the same Save As, Save, Close, and Open controllers used by the UI.
Only native file selection is replaced with `FileSelectorPlatform` results
inside a per-test temporary directory. Saving still collects engine processor
states and writes a real Anthem file; Open still reads, decodes, migrates, and
registers the project before starting its real engine. Runtime options select
the runner's explicit engine and disable hardware audio on reopen. They are
never stored in the project file.

The scenario waits for the old engine's exit before reopening, checks literal
track/pattern names, tempo, and note properties plus persistent IDs in Dart and
the engine, and locates the reopened note in the piano roll. It verifies a clean
dirty flag and new model/engine instances. Additional scenarios cover cancelled
Open and Save As, a failed write that preserves the previous file and dirty
state, ordinary Save without another selection request, and missing/corrupt
files reported by the real application dialog. Closing the last project leaves
New and Open available, with project-specific menu actions unavailable.

The selection override is restored and temporary files are removed after
session cleanup, including on failure. A saved project copy is retained in the
artifact directory for diagnostics; user project and settings locations are
not used. Native dialog UI, third-party plugin state, and audio output are
outside this coverage.

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

The piano-roll driver prepares prerequisite pattern data and viewport settings
through existing models and controllers. It verifies a matching rendered frame
before input, uses the current canvas bounds for each target, and requires mouse
activation before sending history shortcuts. The initial fixture uses the
product's automatic snap mode at a verified 24-tick interval; expected note
properties are literal scenario values, independent of coordinate conversion.
Existing note targets are located by persistent ID in current annotations,
clipped to the visible canvas, and checked for overlapping notes and resize
handles. These locators do not independently prove correct rendering geometry;
the existing painter and geometry tests cover that responsibility.

Artifacts currently include the runner transcript, Flutter version and engine
path, application/engine logs, session IDs/PIDs/exit codes, canvas bounds, and
engine model snapshots. Linux/Xvfb and macOS build jobs upload these even on
failure. The note scenario also saves `drawn.json`, `resized.json`, `undone.json`,
and `redone.json` with viewport diagnostics and engine note state. Persistence
artifacts include
`saved-project.anthem`, `saved.json`, `closed-before-reopen.json`, and
`reopened.json`, with persistent content and both engine lifetimes.

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

## Failure artifacts and CI

Scenarios use `testAppScenario`, which captures thrown assertions and pending
framework errors while the app is still mounted and rethrows the original
failure. Teardown also captures failures reported by the binding, including
unawaited errors that bypass the scenario body. Capture runs before releasing
held input, unmounting the UI, and closing engines. Errors after explicit
disposal retain model and lifecycle evidence and record the missing frame.

Each failed session produces `failure.json` with the original error and stack,
session IDs and executable, Dart project content, active editor/panel/pattern,
selection and held input, arranger target/rendered viewport, and registered
scenario-driver diagnostics. Piano-roll diagnostics include current canvas
bounds, target and rendered time/pitch values, and the last input target.
The report includes a fresh engine snapshot, or a bounded query error when the
engine cannot reply. Individual collector errors are retained in the report;
artifact collection does not replace the original test failure. Application
and engine logs remain in the run's `logs/` directory.

`failure.png` captures the Flutter app surface through a test-owned repaint
boundary, at one pixel per logical pixel. This includes Flutter overlays and
dialogs, and excludes native windows such as system file pickers. When startup
has not produced a frame, the report explains why the screenshot is unavailable.
Engine queries have a two-second deadline. Screenshot capture and writing have
a ten-second deadline to allow cold rasterization and PNG encoding; other
asynchronous artifact operations have three-second deadlines. Cleanup still
runs if collection fails.

Test the integration harness's diagnostic capture and engine cleanup by running
deliberately failing scenarios:

```sh
dart run anthem:cli integration-test --engine /absolute/path/to/AnthemEngine \
  --test-failure-handling
```

This flag selects intentional failures outside normal test discovery. Diagnostics
are already captured automatically when normal integration scenarios fail. The
underlying Flutter process must exit nonzero; the command returns success only after
verifying the original failures, required screenshots and snapshots, and actual
child exits in `stopped.json`. The probes exercise a failed note assertion with
held input and a broken diagnostic collector, framework and unawaited errors,
an unresponsive engine, and startup without a frame. A unique run ID rejects stale
artifacts when reusing an output directory. `verification.json` records the
verified cases.

The Build workflow runs the normal suite and failure handling checks in the Linux
x64 and macOS arm64 jobs, using the **release engine already built by the job**.
The separate desktop smoke workflow has been removed. Flutter integration tests
still compile a debug test application; the release UI bundle is built once and
uploaded before tests. Xvfb supplies Linux's display. Integration diagnostics
are uploaded with `always()` under architecture-specific artifact names.
Windows and the remaining desktop architectures retain their existing builds;
expanding integration coverage to them is a later task.
