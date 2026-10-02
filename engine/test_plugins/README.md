# Controlled VST3 integration fixtures

These are real JUCE VST3 plugins, compiled from the repository's pinned JUCE
submodule. They use no Anthem model, engine, or IPC code. Anthem discovers,
loads, prepares, and restores them through its production VST3 host.

Build them on Linux, macOS, or Windows:

```sh
dart run anthem:cli engine build-test-plugins --debug --jobs 2
```

The optional CMake target is `AnthemTestPlugins`; normal engine and application
builds do not build or ship it. The CLI configures a separate ignored engine
build directory with `ANTHEM_BUILD_TEST_PLUGINS=ON` and writes a manifest of
absolute fixture paths. Nothing is copied to user or system plugin directories.

| Fixture | Behavior |
| --- | --- |
| `AnthemTestInstrument` | Stereo output, MIDI input, monophonic square wave, no audio input. Note-on resets phase and uses MIDI velocity; note-off stops the active note. |
| `AnthemTestEffect` | Stereo input and output; multiplies input by Gain and the selected polarity; no MIDI ports. |
| `AnthemUnconnectedTestEngine` | Sleeps for 60 seconds without connecting to IPC; tests startup timeout and child cleanup on every desktop OS. |

Both plugins expose automatable Gain (normalized 0–1, default 0.25) and Invert
(default false), plus a native JUCE generic editor. JUCE's VST3 wrapper also
exposes its Bypass parameter, which the host-discovery assertions include.
State is versioned JSON
containing those values and an opaque revision counter. Gain edits increment
the counter; state restoration restores its saved value. The counter is not
exposed as a parameter, so resetting the knobs alone cannot reconstruct it.
This is fixture state, not a change to the Anthem project format.

The first integration scenarios check loading/removal/reloading, discovered
ports and parameters, the Flutter device rack, and project save/reopen with new
native instances. They use an offline processing configuration without an audio
device. Actual sample assertions and native editor lifecycle/DPI assertions are
subsequent scenarios; providing an editor does not itself test its visibility.

Keep baseline behavior small and deterministic. Add named variants or explicit
fixture modes when a host regression needs a particular bus layout, parameter
notification sequence, saved state, or editor behavior. Preserve existing
defaults so adding a reproduction does not silently change earlier assertions.
