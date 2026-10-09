# Processor state storage investigation

Investigated on 2026-10-09. This records findings and a proposed direction for
future work; it is not an implemented design. Finish the current processor
metadata review before starting this work.

## Scope

Investigate a common state capture, restoration and preset mechanism for native,
VST3 and future CLAP processors, without requiring large opaque state to pass
through the Dart project model and ordinary model synchronization.

Native sample/wavetable asset management, immutable assets and small snapshots
that reference those assets are **deferred until there is a specific use-case**.
Do not introduce that machinery as part of this investigation. Likewise, do not
require a database, chunk deduplication or a new native state framework up front.

## Current Anthem behavior

### Native processors

Native instance settings are represented by processor model fields and control
input ports' `parameterValue` fields. New nodes receive creation presets; loaded
nodes receive saved project values. Both reach the engine through regular
generated model serialization and synchronization.

During preparation, the engine reports supported ports, factory defaults and
channel counts. Discovery preserves supplied parameter values and fills missing
values. Graph publication initializes runtime parameter bindings from those port
values. Subsequent edits update the bindings through model synchronization.

Native processors do not currently implement opaque `getState`/`setState` data.
This is adequate for existing native settings, but does not establish a general
mechanism for future private processor data that the UI need not understand.

Relevant code:

- [Creation presets](lib/model/processing_graph/processors/native_node_bootstrap.dart)
- [Discovery reconciliation](lib/logic/project_controller.dart)
- [Runtime parameter bindings](engine/src/modules/processing_graph/runtime/node_process_context.cpp)
- [Processor state interface](engine/src/modules/processing_graph/processor/processor.h)

### VST3 processors

`NodeModel.processorState` stores an opaque, base64-encoded snapshot. JUCE supplies
the snapshot through `getStateInformation`; restoring it uses
`setStateInformation`. Saved control-port parameter values are UI mirrors, rather
than an additional source replayed over restored plugin state.

The current initialization work delivers saved state to the engine with the node
model. The engine restores it once per processor lifetime before reporting final
ports and current parameter values. Audio-session re-preparation does not replay
saved state over live edits.

State capture is debounced by one second after plugin changes and also occurs
before saving. Dart assigns a new blob only if it differs from the previous blob.
Because `processorState` is now included in model synchronization, each changed
blob is echoed back to the engine. That echo changes the stored engine model
field; it does not restore the running plugin again.

Removing `@hideFromCpp` enabled initialization to read saved state, but also
enabled these unnecessary incremental echoes. Keeping a field in engine
snapshots while excluding its incremental updates was suggested as a smaller
interim change. That would reduce echoes without solving large state storage.

Relevant code:

- [State capture](lib/model/processing_graph/node.dart)
- [Model synchronization](lib/model/project.dart)
- [Initialization and restoration](engine/src/modules/core/processing_graph_node_initialization_session.cpp)
- [VST3 state delegation](engine/src/modules/processors/vst3_processor.cpp)
- [Capture before saving](lib/logic/main_window_controller.dart)

## Evidence about plugin state

### VST3

VST3 captures and restores complete component state through `IBStream`. Its stream
interface uses binary reads/writes and 64-bit positions. The standard preset
format uses 64-bit chunk lengths and offsets. These interfaces provide no basis
for assuming state is small, or that it must all be held in host memory.
[Component state API](https://steinbergmedia.github.io/vst3_doc/vstinterfaces/classSteinberg_1_1Vst_1_1IComponent.html),
[stream API](https://steinbergmedia.github.io/vst3_doc/base/classSteinberg_1_1IBStream.html),
[preset format](https://steinbergmedia.github.io/vst3_dev_portal/pages/Technical%2BDocumentation/Locations%2BFormat/Preset%2BFormat.html).

There is concrete evidence of audio embedded in plugin state: Vital's host-state
callback serializes synth state, that state includes its sample, and the sample
serializer encodes actual PCM samples into the state. This proves embedded audio
occurs; it does **not** establish that gigabyte-sized snapshots are common.
[Host-state callback](https://github.com/mtytel/vital/blob/main/src/plugin/synth_plugin.cpp#L176),
[state construction](https://github.com/mtytel/vital/blob/main/src/common/load_save.cpp#L84),
[sample serialization](https://github.com/mtytel/vital/blob/main/src/synthesis/producers/sample_source.cpp#L284).

VST3 also has optional stream metadata that identifies project/preset context and
can supply a preset file path. This is context information, not a guarantee that
the state contains or collects every external resource.
[Stream attributes](https://steinbergmedia.github.io/vst3_doc/vstinterfaces/classSteinberg_1_1Vst_1_1IStreamAttributes.html).

### CLAP

CLAP's state extension explicitly covers parameter and non-parameter state,
project reloads, instance duplication and host presets. Capture and restoration
use stream callbacks; plugins must handle partial reads and writes. A host can
back those streams with files instead of accumulating the result in memory.
[State extension](https://github.com/free-audio/clap/blob/main/include/clap/ext/state.h),
[stream interface](https://github.com/free-audio/clap/blob/main/include/clap/stream.h).

The optional state-context extension distinguishes project, preset and duplication
operations. A common Anthem state interface should leave room for that context,
rather than assuming all restoration operations have identical semantics.
[State contexts](https://github.com/free-audio/clap/blob/main/include/clap/ext/state-context.h).

Two relevant extensions are currently in CLAP's **draft** directory:

- Resource directories let plugins store resources in host-provided directories,
  using relative references. They distinguish shared read-only resources from
  instance-specific writable resources and discuss copying and cleanup. This is
  evidence that external resources are a recognized concern, not a feature that
  every CLAP plugin can be assumed to support.
  [Resource-directory draft](https://github.com/free-audio/clap/blob/main/include/clap/ext/draft/resource-directory.h).
- Undo integration lets plugins participate in host history and optionally
  provide versioned undo/redo deltas. Without a delta, state snapshots are the
  fallback. Do not depend on adoption or stability of this draft for the basic
  storage design.
  [Undo draft](https://github.com/free-audio/clap/blob/main/include/clap/ext/draft/undo.h).

## Memory and transport costs in Anthem

The current VST3 capture path has two base64 layers:

1. JUCE captures component and controller state in memory, encodes each as base64
   inside XML, then writes the XML into a `MemoryBlock`.
2. Anthem base64-encodes that result for its JSON response and stores the string
   in Dart. Changed strings are currently echoed through model synchronization.

Ignoring XML overhead and additional controller state, two base64 layers expand
the original VST state by approximately `(4 / 3)^2`, or **1.78 times**. This is an
encoding-size calculation, not a measured peak-memory figure. Capture, encoding,
IPC and parsing also create temporary buffers.

See [JUCE's VST3 wrapper](engine/include/JUCE/modules/juce_audio_processors_headless/format_types/juce_VST3PluginFormatImpl.h)
(`getStateInformation` and `appendStateFrom`) and
[Anthem's state command handler](engine/src/modules/command_handlers/processing_graph_command_handler.cpp).

Desktop project saving already streams JSON into gzip, but that does not remove
the large strings retained in the model or the capture/IPC costs. Saving refreshes
all plugin states using `Future.wait`, which is another consideration when
measuring memory with multiple instances.
[Project-file writer](lib/logic/project_file/io_io.dart).

A file store would reduce persistent duplicate snapshots and large IPC transfers.
It would not remove a plugin's own live working data. Nor would it immediately
remove all capture-time allocations: the JUCE API currently used by Anthem
requires a complete `MemoryBlock`. True VST streaming would be separate adapter
work; CLAP's stream interface accommodates it directly.

## Candidate storage contract

Use a common processor-state service that returns durable references:

```text
captureState(processor, context) -> state reference and metadata
restoreState(processor, state reference, context)
```

The processor or its adapter owns the encoding. The UI can retain a reference
without understanding the contents or receiving the complete payload. Native,
VST3 and CLAP processors can share this contract while using different encodings.

A first implementation could use files and a small manifest. A database may be
useful for indexing later, but is not required to store opaque blobs. References
should be stable identifiers resolved by the store, rather than permanent
absolute paths embedded in project files.

Important properties to settle before implementing:

- A snapshot is independently restorable and is not overwritten while history
  or a saved project references it.
- Successful capture acknowledges a complete stored object, rather than a
  partially written file.
- Storage outlives an engine process, so engine restart can restore state.
- Unsaved projects have a storage location; Save As and project transfer retain
  the referenced objects.
- Project saving includes or otherwise preserves all required snapshots.
- Missing plugins retain existing saved state rather than replacing it with an
  empty or factory snapshot.
- Private processor state and UI-visible editable fields have explicit ownership
  and reconciliation rules. Loading state must leave controls and DSP consistent.

Both processes could access files through the same storage abstraction. This
leaves room for future audio access without designing native audio asset storage
now. Opaque plugin state is not directly usable as waveform data, and a stored
snapshot is not automatically self-contained if it references external files.

The filesystem implementation also needs a platform boundary: desktop shared
paths cannot simply be assumed to work unchanged on web.

## Undo and redo

Ordinary parameter edits can remain small commands containing the parameter ID
and old/new values. Anthem already uses this approach in
[SetParameterValueCommand](lib/logic/commands/parameter_commands.dart).

For preset loads or arbitrary state changes, a command can hold before and after
snapshot references. Undo restores one stored object; redo restores the other.
The command does not need to retain the payload in RAM. Objects must remain
available while referenced by the project, undo history or recovery data; removing
a processor must not prematurely delete state required to undo that removal.

Opaque snapshots can still be expensive on disk. If a parameter change produces
a different gigabyte-sized blob, storing both snapshots may require two large
objects. Whole-object deduplication only helps identical bytes. Compression or
chunk deduplication cannot be assumed to make this cheap, and are not initial
requirements.

Generic state-change notifications do not necessarily supply the before state
or identify semantic undo boundaries. A snapshot policy and a retained baseline
are needed before promising undo for arbitrary plugin-editor actions. CLAP's
draft undo deltas could improve this for cooperating plugins, while snapshots
remain the fallback.

## JUCE ValueTree

`ValueTree` adds hierarchical properties, listeners, optional `UndoManager`
integration and binary/XML persistence. These can be useful for complex private
native processor state. Ordinary copies reference the same mutable tree;
independent copies require `createCopy()`.
[ValueTree documentation](https://docs.juce.com/master/classjuce_1_1ValueTree.html).

It does not supply a shared file store, automatic schema migrations or integration
with Anthem's Dart command history. It therefore does not by itself solve the
storage, versioning or cross-process ownership questions above. Serialization
alone is not a strong reason to replace existing typed models and reflect-cpp.

`AudioProcessorValueTreeState` adds integration with JUCE processor parameters.
Its capture/replacement operations use locks and are not real-time safe. Anthem's
native processors use Anthem's parameter system, so that integration is not an
automatic fit.
[APVTS documentation](https://docs.juce.com/master/classjuce_1_1AudioProcessorValueTreeState.html).

Choose typed structures, reflect-cpp or `ValueTree` when a particular native
processor's requirements make the tradeoff concrete. A shared state service need
not prescribe one internal representation for every processor.

## Possible implementation sequence

These are future review boundaries, not authorization to begin implementation:

1. Finish the current processor metadata review.
2. Define the state-reference, storage-lifetime and capture/restore contracts.
   Resolve project packaging, unsaved-project storage and restart behavior.
3. Introduce file-backed VST snapshots and small IPC references, preserving
   initialization ordering and missing-plugin state. Handle project-file changes
   in versioned migrations, keeping model `fromJson()` current-schema-only.
4. Add preset operations and undoable state restoration through the common
   interface, with explicit reconciliation of UI-visible values.
5. Integrate CLAP when hosting support is implemented. Treat draft resource and
   undo extensions as optional capabilities.

Use controlled JUCE test plugins to measure capture size, memory, transport and
restoration with bounded configurable state sizes. Verify project reopen, engine
restart, Save As, missing plugins, failed writes and undo retention. Avoid starting
with a gigabyte allocation on this development machine.

Native private-state encoding, audio assets, deduplication and true VST streaming
can be separate work when a specific use-case or measurement justifies them.
