# Processor state storage investigation

Investigated on 2026-10-09; implementation notes revised on 2026-11-01. This records findings and decisions for future work. Desktop file storage, engine storage requests, folder-based project save/load, and file-backed VST state are implemented. Native and hosted processors now share engine-owned parameter values and file-backed snapshots. Native initialization uses engine defaults and descriptions with independent creation overrides. Live state application and preset operations are the next steps.

## Scope

Investigate a common state capture, restoration and preset mechanism for native,
VST3 and future CLAP processors, without requiring large opaque state to pass
through the Dart project model and ordinary model synchronization.

Native sample/wavetable asset management, immutable assets and small snapshots that reference those assets are **deferred until there is a specific use-case**. Do not introduce that machinery as part of this investigation. Likewise, do not require a database or chunk deduplication up front. The next stage includes a basic native parameter-state encoding; additional private-state schemas should follow concrete processor requirements.

## Agreed storage direction

Use a per-project asset store managed by the UI. On desktop, the engine requests access through IPC and reads or writes the files directly. IPC carries relative file paths, absolute access paths and access tokens, rather than the stored bytes. Permanent file references are category-qualified paths relative to the project root, such as `plugin states/Preset 01.bin`, so moving a project does not invalidate them. UUID filenames are the default; callers can supply a base name and extension for readable numbered names. Once committed, the name remains stable even if the source track is renamed.

Use a project directory containing the JSON document and asset files. This keeps
the files accessible for inspection and extraction. Define the directory layout
and save workflow when implementing the new project format; a database or archive
is not needed for the first implementation.

A write starts with a private temporary file. After the writer closes it, the
store commits the completed object and returns its relative path to consumers.
Committed processor snapshots are not edited in place: a later capture creates
a new object, preserving any earlier snapshot needed by the project or history.
Read access prevents deletion until the reader releases it. Separately, the store
must retain objects needed by project state, undo history or recovery data even
when nobody is reading them.

Support two uses of temporary storage:

- **Unsaved project data:** an unsaved project needs a working store for snapshots
  and other data that must accompany its first save. Treat this as project data
  even though its location is temporary. Preserve it across engine restarts and
  transfer the required objects on save without changing their relative paths. Release it
  when the project is closed or discarded, after stopping active access. Recovery
  retention must be considered before deleting abandoned working stores.
- **Session cache data:** derived files, such as decompressed audio used during a session, belong in categories marked as regenerable caches. These folders share the project root, are excluded from the saved project, and are deleted when the store closes after all access has ended. Audio decompression itself is future work.

Both uses of temporary storage belong to a project session, rather than an engine process, so restarting the engine does not remove files still needed by the UI or project. Their different retention rules remain explicit in the category definitions.

The existing IPC transport already carries messages in both directions. Extend
request/reply handling so the engine can request storage operations and the UI
can answer them. The UI must service these requests while awaiting engine work,
and the engine must not block its message thread while waiting for a UI reply.
Storage requests and file I/O do not run on the audio thread. Desktop file paths
also require a platform boundary; they cannot be assumed to work unchanged on web.

## Current Anthem behavior

### Shared parameters and snapshots

Native processors and plugin hosts keep their base parameter values in the engine. Explicit edit requests return the accepted value and display text. The Dart model keeps an observable display cache and a transient pending value, rather than sending parameter values through ordinary model synchronization. Runtime graphs borrow the processor's parameter storage, so rebuilding a graph preserves live settings.

Automation supplies effective processing values without replacing the base settings. For VSTs, the adapter applies effective values to JUCE and ignores automated parameter reports when updating the base. Removing a control connection returns processing to the base value. The current adapter still uses the first control sample of each block; sample-accurate delivery is deferred.

A snapshot contains normalized base parameters and an optional private payload. Existing native processors need only the common parameters; VSTs add JUCE's opaque bytes. `NodeModel.processorStateRetentionId` identifies the project-owned file claim. `ProjectModel.fileRetentions` stores the asset store's serialized project claims; commands and saved documents retain independent runtime claims.

The engine obtains access before capture, then captures, hashes and writes synchronously on the message thread. Unchanged snapshots reuse the previous file using its byte length and SHA-256. The complete buffer is released before waiting for storage replies. Failed captures preserve the previous reference. Debounced edits, Save, and removal commands use this same capture path for native processors and plugin hosts.

Initialization restores the private payload followed by the common base values, prepares the processor again, and reports its final ports and values before graph publication. Creation settings apply once when no saved snapshot exists. Re-preparation of an existing instance does not replay saved state over live edits.

JUCE still allocates a complete `MemoryBlock` during capture and restoration. File storage removes the opaque payload from Dart and ordinary IPC, but does not eliminate that engine-side allocation or JUCE's internal encoding. Streaming VST state remains separate work.

Prealpha.1 imports construct common snapshots from their saved parameters and embedded plugin state using migration-local file writes. The raw JSON is migrated before the current model and storage are constructed. Legacy import necessarily decodes the old payload in Dart; current-format projects contain only file references.

Relevant code:

- [Parameter ownership](engine/src/modules/processing_graph/processor/processor.cpp)
- [UI edit coordination](lib/logic/parameter_controller.dart)
- [Common snapshot encoding](engine/src/modules/core/processor_state_snapshot.cpp)
- [Storage access and capture](engine/src/modules/core/processor_state_storage.cpp)
- [Initialization and restoration](engine/src/modules/core/processing_graph_node_initialization_session.cpp)
- [VST3 adapter](engine/src/modules/processors/vst3_processor.cpp)

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

The previous embedded-state path used two base64 layers:

1. JUCE captures component and controller state in memory, encodes each as base64 inside XML, then writes the XML into a `MemoryBlock`.
2. Anthem encoded that block again for its JSON response and retained the result in Dart, including incremental model synchronization.

Ignoring XML overhead and additional controller state, two base64 layers expand the original VST state by approximately `(4 / 3)^2`, or **1.78 times**. This is an encoding-size calculation, not a measured peak-memory figure. The file-backed path removes the outer Anthem encoding, the payload in Dart, and its IPC transfers. JUCE's internal encoding remains.

See [JUCE's VST3 wrapper](engine/include/JUCE/modules/juce_audio_processors_headless/format_types/juce_VST3PluginFormatImpl.h) (`getStateInformation` and `appendStateFrom`) and [Anthem's state storage](engine/src/modules/core/processor_state_storage.cpp).

Desktop project saving streams JSON into gzip. Plugin capture now writes state files directly in the engine. A capture buffer exists only during the synchronous capture/hash/write operation; pending IPC replies retain metadata rather than opaque bytes. In the Linux integration fixture, a 1 MiB plugin payload produced approximately 1.4 MiB of JUCE state stored outside the project document. The common snapshot adds a small metadata header. These are file sizes, not memory measurements. [Controlled fixture](engine/test_plugins/test_plugin.cpp), [persistence scenario](integration_test/plugin_test.dart).

**Follow-up to retain:** file storage does not remove a plugin's own working data, JUCE's complete capture/restoration buffers, or its internal base64/XML encoding. Measure those engine-side costs separately. True VST3 streaming would require adapter work; CLAP's stream interface accommodates it directly.

## Candidate storage contract

Use a common processor-state service that returns durable references:

```text
captureState(processor, context) -> state reference and metadata
restoreState(processor, state reference, context)
```

The processor or its adapter owns the encoding. The UI can retain a reference
without understanding the contents or receiving the complete payload. Native,
VST3 and CLAP processors can share this contract while using different encodings.

The asset store resolves category-qualified relative paths to runtime filesystem paths. Permanent absolute paths do not belong in project files.

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

It does not supply a shared asset store, automatic schema migrations or integration
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

## Implementation sequence

Stages 1–4, generic node suspension, retained snapshot save/load, and undoable state restoration are implemented. Project storage uses shared asset scopes, and desktop and browser projects support ZIP import and export. This completes the processor-state and storage work for prealpha.2.

User-facing preset management and CLAP integration remain future features. The deferred native asset and private-state work described above is outside this release's scope.

1. Build the desktop asset store and its tests: relative file paths, temporary writes,
   commit/abort, read access, retention and deletion, and separate unsaved-project
   and regenerable cache categories. This stage leaves the current project format
   and plugin capture path intact.
2. Add engine-originated IPC and storage requests, with a C++ client for write transactions, read access, and deletion. Use one storage API for direct UI calls and engine requests. File scopes group read, write, and retention tokens; the IPC handler associates requests with the engine process's file scope. Verify replies, errors, lost replies, and cleanup after the engine stops, while preserving committed files and project-owned references.
3. Introduce folder-based projects and file-backed VST snapshots, preserving
   initialization ordering, missing-plugin state, engine restart and Save As.
   Handle project-file changes in versioned migrations, keeping model
   `fromJson()` current-schema-only. Replace payloads in the model and IPC with
   small state references.
4. Give native processors and plugin hosts one engine-owned state contract. Use it for parameter editing, project restoration, presets, and undoable state restoration, with explicit reconciliation of UI-visible values.
5. Integrate CLAP when hosting support is implemented. Treat draft resource and
   undo extensions as optional capabilities.

Use controlled JUCE test plugins to measure capture size, memory, transport and
restoration with bounded configurable state sizes. Verify project reopen, engine
restart, Save As, missing plugins, failed writes and undo retention. Avoid starting
with a gigabyte allocation on this development machine.

Native private-state encoding beyond the current parameters, audio assets, deduplication, and true VST streaming can be separate work when a specific use-case or measurement justifies them.

## Stage 4: common processor state

Parameter editing, capture and startup restoration now use the shared contract below. Live state application and presets remain planned. Editing requires a running engine and a ready processor for both native processors and plugin hosts.

### Ownership and snapshots

The engine owns a processor's live settings and supplies its port and parameter descriptions, including factory defaults, formatting and visual baselines. Dart owns the project structure, routing, explicit reset overrides, state-file references, and undo history. Descriptions and parameter values cached in Dart let saved projects display controls before initialization or when the engine is unavailable; updating a value cache must not itself change engine settings. Initial values chosen when creating a device are a separate, one-time input. Host bindings, such as the track assigned to a sequencer provider, remain synchronized graph configuration.

One engine parameter system maintains base values for native processors and plugin hosts. A base value is the stored, editable setting; an effective value is the result of applying automation and modulation. Processing uses effective values without writing them back into the base values. Native processors consume these values directly, while the VST adapter delivers them to JUCE. Parameter editing, control routing, and the policy for accepting processor-originated changes belong to the shared system.

Parameter storage belongs to the processor instance, and runtime contexts borrow stable bindings that outlive individual compiled graphs. Graph publication and audio-configuration changes can then preserve live settings without reconstructing them from a potentially stale UI cache. Reconcile parameter descriptions by stable control-port ID, preserving existing base values and initializing new ones before control signals are applied. Missing ports keep their saved values through the existing unavailable-port handling.

Each snapshot stores a schema version, normalized base parameter values keyed by stable control-port IDs, and any processor-specific state. Existing native processors need only the common parameter data; private durable settings can be added when a processor needs them. The VST adapter includes JUCE's opaque state. Restore processor-specific state first, then apply the common base values before automation resumes. The engine captures and restores both parts together through the asset-storage machinery. Node and track IDs, connections, cached descriptions and values, and reset overrides remain project data. Temporary DSP data, such as the tone generator's running phase, is not automatically preset state.

The preset identifies which processor it belongs to, independently of the node where it is applied. The engine owns the common snapshot format, and each processor owns the encoding and version handling of its private payload. Dart does not need to decode state files, and this does not require another shared definition file or additional Dart model code generation.

### Observable parameter state in the UI

Keep observable parameter fields on `NodePortModel` as the UI's view of engine state. One handler applies initialization snapshots, accepted edits, and processor-originated changes to those fields. Existing controls continue reading through `ParameterUiBinding` and rebuilding through MobX. Editing goes through the common engine API; changing a cached value must not send a model update back to the engine. A separate parameter registry or state-management system is not needed for this checkpoint.

Distinguish the confirmed base value, the effective value used for visualization, and any pending edit. During a drag, show the pending value immediately while awaiting confirmation. Reconcile it with the accepted value or discard it on rejection; an older reply must not overwrite a newer edit. Keep this coordination in the existing parameter-editing machinery, and finish the undo gesture once its final accepted value is known.

Use `@hideFromCpp` for a cached value retained in project JSON as a last-known preview; that preview is not a restoration source. Use `@hide` for transient observable state, including pending edits and runtime display data. Effective-value visualization should use the existing visualization transport at a suitable display rate. Visualization reports must not mark the project dirty or create history entries. Preserve cached displays when the engine stops, with editing governed by the existing readiness state.

### Base values, automation, and modulation

Keep today's behavior in which an incoming control signal replaces the base value during processing. Future modulation may combine a base value with several signals in other ways; that evaluation must remain shared by native processors and plugin hosts. Do not make the presence of a connection an inherent prohibition on editing a base value. Distinguish explicit base-value edits from reports of effective values so richer modulation can allow base edits while control signals continue. The modulation algorithms themselves are future work.

For current absolute automation, preserve a controlled parameter's known base value when the processor reports value changes; accept reported changes for uncontrolled parameters. When control disconnects, processing must return to the base value. Late notifications from earlier automated processing must not overwrite it after disconnection. Apply the same policy to native processors and plugin hosts, and keep base-value reports distinguishable from effective-value reports in the UI and history handling.

A preset loaded through Anthem explicitly replaces the base values from its snapshot. A preset loaded inside a processor's own editor may change parameters while automation continues, without giving Anthem an accurate snapshot of the new unautomated settings. Use the same notification policy for this case: preserve known bases for controlled parameters and accept changes for uncontrolled parameters. Do not attempt to reconstruct the hidden preset's original values from a scan taken during automation.

Opaque state may contain the effective parameter values at capture time, so its bytes can differ at different playback positions. Preserve the bytes as supplied and store the common base values alongside them; applying those base values after restoration provides the intended settings. Accept that unchanged base values do not guarantee an identical opaque snapshot or matching content fingerprint.

The current VST adapter delivers only the first control sample of each block. Sample-accurate VST automation is deferred while waiting for JUCE support; evaluate a future JUCE release before considering a custom implementation. This stage preserves the current delivery resolution. Richer modulation and improvements to VST automation delivery must use the shared parameter semantics above. Any required JUCE integration change needs discussion before implementation.

### Cleanup included in the combined checkpoint

| Previous handling | Replacement |
| --- | --- |
| Parameter commands synchronized model values and sent a separate VST edit. | All edits use the processor API and apply its accepted value to the UI cache. |
| `NodePort` forwarded synchronized values into the current runtime context. | UI previews are excluded from C++ synchronization; the forwarding path is removed. |
| `NodeProcessContext` allocated parameter values each time the graph was compiled. | Contexts borrow stable processor-owned values. |
| Parameter requests cast to `VST3Processor` and were excluded on WASM. | Dispatch uses the common processor contract, including discrete-value normalization. |
| Initialization and notifications separately applied reported values. | Both use the same observable-cache update function. |
| UI gestures and plugin-editor gestures used separate value-changing paths. | Both record the same accepted-value command; UI gestures await replies, while plugin gestures use reported boundaries. |
| Capture and removal helpers excluded native processors. | All ready processors use the common snapshot and retention machinery; stateless processors can return no state. |

The removed `NodeModel.isThirdPartyPlugin` flag also made [`ProcessingGraphModel.addConnection`](lib/model/processing_graph/processing_graph.dart) validate native endpoints immediately while permitting unresolved plugin endpoints. Both kinds depend on engine discovery, so unavailable ports now represent unresolved endpoints consistently. Native factories can still have tests for their expected port IDs. Historical migrations may continue reading the old field as part of the old schema.

These changes reuse the current command, IPC, port-reconciliation, and storage machinery. Plugin-editor windows and format availability remain capabilities of particular processors; they do not need a uniform implementation to share state handling.

### Creation, restoration, and edits

- **Creation:** create the processor, prepare it, and apply explicit initial settings once when there is no saved snapshot. A regular track's −10 dB Utility gain must survive this transition. Keep those inputs available until a committed snapshot replaces them, so a restart before the first capture still has the intended defaults. Factory defaults and project reset targets remain separate. Do not infer creation settings from every subsequent UI cache update.
- **Project open or engine restart:** during initialization, obtain read access to the retained snapshot, read and restore it, prepare again if necessary, then report the final ports and values. Complete this sequence before the processor's first graph publication. The processor cannot yet be executing, so initialization needs no suspension request or audio-thread acknowledgement. Initial restoration happens once per processor instance; changing sample rate or rebuilding a graph must not replay a snapshot over live edits.
- **Parameter edits:** use the same processor operation for native controls, hosted-plugin controls, and parameter undo/redo. Retain the small old/new-value commands for ordinary edits. Complete a gesture once its final accepted value is known; reports of that edit must not create another history entry. An unavailable engine or processor must reject the edit before changing history; a stopped engine is not an alternate native editing mode.
- **Preset application and state undo/redo:** retain a before snapshot, apply the replacement, obtain the resulting ports and values, and update routing through the existing discovery/publish path. Keep the before and after snapshots for history. Updating the model's saved snapshot reference after a capture must not itself trigger another restoration.

### Native initialization

Native and hosted processors use the same engine-originated initialization reports. Dart factories retain stable routing endpoints without duplicating native factory values or formatting; `NativeParameterPreset` is removed. Creation overrides remain a small optional map of normalized parameter values, independent of preset save/load. They require no preset object, file, exported binary, shared initialization schema or additional code generator.

The engine initializes its factory state, restores a saved snapshot when present, and otherwise applies creation overrides once. Retain those overrides until the first successfully retained snapshot. Ordinary source tracks request a Utility gain of −10 dB and separately choose −10 dB as the project reset target; groups, returns and the master use the processor's unity-gain default. An arbitrary creation override does not implicitly change a reset target.

Fixed visual properties such as `normalizedVisualBaseline` belong in the parameter description, alongside display mode and units. Cache those descriptions and confirmed parameter values in the saved project so controls remain inspectable without the engine. New controls can wait for discovery where their descriptions are not yet known. Preserve explicit project reset targets independently of description refreshes.

Stable native port IDs and data types can still be used to construct routing before discovery, including the default project. Availability and runtime channel counts are confirmed before audio publication. Do not introduce a blanket running-engine requirement for graph structure changes or redesign all routing around deferred creation. Operations that need live state continue to enforce their actual readiness requirements. A new project may assume a functioning engine; offline native creation does not justify another metadata path.

Native processor IDs, port IDs, parameter meanings and normalized mappings are compatibility contracts. An incompatible successor should use a new processor identity while retaining the previous implementation as legacy. Runtime channel counts may still vary, and private state requires compatible or versioned decoding. No legacy-processor framework is needed for this cleanup.

Verify engine defaults without overrides, contextual creation and independent reset targets, cached display after save/load without engine startup, pending controls, saved routing, snapshot precedence and restart before capture, and preservation of live settings through graph recompilation and audio re-preparation. Update the current unreleased migration when moving parameter metadata; keep detailed snapshot assertions in their owning tests. This work does not change the snapshot format, implement presets or add live-state suspension.

### Live state replacement

Live state replacement builds on `GraphProcessor::pauseNode`. Acquire read access to the state file first, then request a pause claim. The atomic entry gate prevents further processing calls; if a call is in progress, acknowledgement waits for it to finish. An idle processor can acknowledge without another audio callback. Processing threads do not block, allocate, or post acknowledgements. The node still completes scheduler bookkeeping and produces cleared outputs while suspended; other nodes continue. After acknowledgement, the message thread can replace state and prepare the processor. If the ports changed, reconcile them and wait until a runtime graph with compatible buffer bindings is active before releasing the claim. A state change that preserves the port layout does not itself require graph replacement. Use the same suspension mechanism for state replacement and port reconfiguration; independent claims prevent one operation from resuming a processor still needed by another.

A node's processor reference is non-nullable and fixed for its lifetime. Replacing the processor instance requires replacing the node; state restoration keeps the same instance. Runtime graphs retain the source node, which owns that processor. Suspension belongs to the processor instance and survives replacement of its compiled graph context. Disconnected nodes are still scheduled in the current executor, so disconnected routing needs no separate suspension path. Initial restoration follows the initialization sequence above. A pending pause can complete after the last processing call exits even if the audio session stops; held claims remain valid across restart. Node removal cancels pending requests and invalidates held claims. The gate also covers render processing. The master output cannot be paused; its configuration changes through audio-session stop/start coordination, and output readers use its buffer normally. The retained snapshot checkpoint must define the policy for applying state during an active offline render.

Investigate how JUCE handles plugin-initiated I/O changes before implementing this coordination. Any required change to JUCE or its integration must be discussed with the engineer before implementation; investigation alone does not authorize that change.

Preserve the checks for stale node instances, engine restarts, unavailable ports, missing plugins, and failed captures. These express real lifetimes and failures. If restoration partially changes a processor before failing, attempt to restore the retained before snapshot; if that also fails, keep its state files and leave the processor unavailable rather than reporting success. Serialize state operations with edits to the affected processor, and ignore obsolete completions after replacement or restart. A failed history operation must leave its history position available for retry.

After engine loss, preserve the last committed snapshot and any initial settings still needed to create a new instance. A UI parameter cache cannot reconstruct private processor data, so it must not silently replace that snapshot. Project structure can still be copied or saved using retained state; loss of edits newer than the last successful capture remains a recovery concern for native and hosted processors alike.

### Compatibility and platform boundaries

Project restoration uses the common snapshot format. The prealpha.1 migration converts its saved native parameter values and embedded VST state into that format, including saved VST parameter values where available. Keep these writes and JSON conversions inside the migration, before constructing the current model or opening the current asset store. Target the existing unreleased `prealpha.2` format; earlier development versions of `prealpha.2` do not need another compatibility path. Test native gain and balance as well as VST state, and keep current `fromJson()` generated and current-schema-only.

The generic parameter contract must work for native processors on WASM. File-backed browser persistence still depends on the separate web storage and ZIP checkpoint. File-backed captures and removal undo that retains snapshots also depend on that backend; unsupported storage must fail before mutating nodes or advancing history. Until that exists, do not present a document-only export as a complete project containing processor snapshots. Automatic engine restart, broader engine-status UI, and arbitrary plugin-editor undo boundaries remain separate work; this stage should provide one consistent readiness/error policy that those features can use.

### Review checkpoints

The first checkpoint combines live parameter ownership, the common editing API, snapshot capture, startup restoration, and migration. These are implemented together so review does not depend on a temporary native/VST split.

The base-value and automation capture policy is agreed above. Before implementing live state application in the retained snapshot checkpoint, investigate JUCE's plugin-initiated reconfiguration path and discuss any required integration change with the engineer. Offline-render coordination also needs verification in that checkpoint. Sample-accurate VST automation and richer modulation are deferred and do not block these checkpoints.

1. **Engine-owned parameters and common snapshots.** Establish lifetime-stable base values for native processors and plugin hosts, the common parameter API, explicit initial settings, and common reports. Retain the observable UI view and add pending-edit reconciliation. Implement the shared snapshot encoding for base values and processor-specific state, broaden capture and restoration, and update the historical migration before removing the old model-driven edit and persistence paths. Remove type-based capture gates and the remaining stored type flag. Verify accepted values, reactive controls, rejected and out-of-order edits, gestures, uncontrolled processor edits, controlled-value notifications, disconnection and late notifications, −10 dB creation defaults, graph recompilation, and native requests on WASM. Verify mixed native/VST project reopen, engine restart, Save As, missing processors, stateless nodes, unchanged snapshots, and capture failures. Cover capture during automation, restoration of saved bases, parameter-description refreshes, and processor-internal preset changes under the agreed notification policy.
2. **Generic node suspension.** Establish an asynchronous pause claim that confirms processing is quiescent, supports overlapping owners, survives graph replacement, and releases without making processing threads wait. Reject suspension of the special master output node. Cover node removal, engine shutdown, audio-session stop/restart, cleared outputs, and continued scheduler progress. This engine primitive does not apply snapshots or manage history.
3. **Retained snapshot save/load.** Save a processor snapshot and transfer a retained reference to the UI. Loading borrows that reference so it remains reusable. Build loading on node suspension, with result reconciliation, port reconfiguration, failure recovery, and offline-render coordination contained below the public API. Verify JUCE's plugin-initiated reconfiguration behavior before changing its integration. Test file ownership independently of undo and preset controls.
4. **Undo and presets.** Build a small command that retains before/after snapshot references and calls the save/load API. Test repeated undo/redo, disposal of discarded history, concurrent edits, stale replies, and failed history operations. Add processor identity and format version to the preset envelope and use the same loading API. Test incompatible presets, invalid state, and file failures before connecting the workflow to user controls. Preserve the working processor and retained recovery state on failure.

## Category folders and project roots

The desktop store supports configurable category folders. Only `plugin states` is defined for now; categories for audio and derived caches can be added when those features need them. Each category declares whether it contains required project data or regenerable cache data. Files are referenced by category-qualified relative paths, such as `plugin states/Preset 01.bin`. Filenames are reserved independently within each category. The store reopens configured categories by scanning their files and preserves unrelated folders and the project document.

`ProjectStorage` accepts an explicit root, which it preserves on close. `ProjectStorage.temporary()` chooses a fresh temporary root for an unsaved project, creating directories only when files are first needed. Temporary storage can be closed while keeping required data for recovery, or discarded after saving elsewhere or explicit user dismissal. An explicit root cannot be discarded through this API. Cache categories are deleted on close in either case.

First save can copy the completed, non-cache files listed by `ProjectAssetStore.projectAssetPaths` to a stable root without changing their relative paths. Consumers must finish using the old absolute paths before the temporary root is discarded. Desktop Save and Save As now perform this transfer. The open project keeps its existing storage root so that active engine and UI read paths remain valid; temporary roots are discarded when that project closes.

## Web storage and portable archives

Complete project ZIP download is a requirement for web support. The archive must contain the project document and all required files from persistent categories, using the same relative paths as desktop projects. Regenerable caches are excluded. The browser controls the download destination and may prompt; the application must not require directory-picker support to provide export. A download being initiated is not confirmation that it finished, and must not trigger deletion of the live working project. [Browser download behavior](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/a#download).

OPFS is a candidate web backend, with Emscripten filesystem integration still to be verified in Anthem. Archive creation should read files incrementally and avoid accumulating the project payload in Dart memory. A temporary OPFS archive exposed as a browser File is one candidate download path; validate its memory use and lifetime with a real download before selecting the implementation. [OPFS](https://developer.mozilla.org/en-US/docs/Web/API/File_System_API/Origin_private_file_system), [file handles](https://developer.mozilla.org/en-US/docs/Web/API/FileSystemFileHandle/getFile).

Import into a separate staging directory and activate the project only after loading succeeds. Check API availability and estimated storage headroom first, accounting for extraction, required working data, and export staging. Estimates do not reserve space, so actual writes must also handle quota and filesystem failures. On failure or cancellation, stop any import-related engine work, release file access, remove the incomplete import, and then show a clear user-facing error with the desktop version as an alternative. Preserve the original archive and any projects already open. Failed archive export must preserve the live project and remove only the incomplete export. [Storage estimates and quota failures](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria).

Verify import, editing, ZIP download, and reopening the downloaded project on desktop before accepting the web backend. Include quota exhaustion partway through import, cancellation, cleanup failures, and failed export. Define conservative supported-size limits from these measurements rather than assuming every project fits browser storage or memory.

## Initial asset store

[`ProjectAssetStore`](lib/logic/storage/project_asset_store.dart) groups read, write, and retention tokens into file scopes. UI clients call its API directly; the engine's IPC handler forwards requests using a file scope owned by that engine session. Read tokens prevent deletion during file access; retention tokens keep files available for project state or history. Writes are published after the writer closes its temporary file.

Committed files may have a cached content fingerprint containing their byte length and SHA-256 digest. Writers can supply it when committing; otherwise the store calculates it in chunks when first requested. Read requests can include this metadata, allowing the engine to compare a new snapshot without rereading the previous file on every capture. Fingerprints are not saved in a separate index: reopening starts a new cache, and deleting a file discards its metadata even if the path is reused. The cache assumes committed files are not edited in place while the store is open.

A client must finish file I/O and close OS file handles before closing its file scope. The store waits for accepted operations, aborts unfinished writes, and releases that scope's tokens. Committed files and other scopes' access remain. Deletion is explicit, and reopening preserves unreferenced objects and abandoned writes.

[`ProjectStorage`](lib/logic/storage/project_storage.dart) owns the store for the lifetime of an open project. An engine session closes its file scope after its process stops; UI access and project/history references can last until project closure. Project close waits for engine disposal, and all file scopes must close before the store can close. Explicit roots are preserved and temporary roots are discarded. Recovery discovery and retention policy remain future work.

The engine can begin, commit, and abort writes; acquire and release reads; retain and release references; and request deletion of unused files. The C++ client and production UI dispatcher are exercised together in real-engine tests, including startup, render request holds, process exit, restart, and a lost access reply. The node model now stores relative state-file references. The desktop filesystem backend has an explicit unsupported boundary on web, tested with both JavaScript and Dart WebAssembly compilation. An OPFS backend and Emscripten filesystem access are deferred to a separate stage so that import cleanup, quota failures, engine restarts, and ZIP download can be verified together.

## Folder project checkpoint

Desktop Save As asks for a new project folder name and location, initially using the configured projects directory. A folder named `Song` contains `Song.anthem` and any required category files, such as `plugin states/State 01.bin`. Open selects the `.anthem` document inside that folder.

The document keeps the existing compressed JSON encoding and container header. Open reads `savedInSoftwareVersion` before migrations update it: versions before `prealpha.2` are imported as unsaved projects, while `prealpha.2` and later use the selected document's parent directory as storage. This cutoff is fixed at the first folder-based release, independently of the running software version. Unreleased development files are not a separate compatibility target.

First save and Save As assemble a new folder before publishing it. Ordinary Save copies files referenced by the current model when the working root differs from the saved folder, replacing existing destination copies, then replaces the document with a completed temporary file. Saving in place leaves stored files where they are. Pending writes are excluded. No unused saved files are deleted during Save.

Save As changes the save destination while keeping the open asset store at its existing root, so active engine and UI read paths remain valid. Newly written files remain in that working root and are copied on subsequent saves. Temporary roots are discarded when the project closes; reopening uses the saved folder as the store root. Moving the live store to a new root would require coordinating existing readers and is deferred.

Older standalone `.anthem` files open as unsaved projects and show a notice to save as a folder. The original file is preserved. JSON migrations still run before model deserialization. Web still offers document-only downloads during development. Current-version projects require folder storage and cannot yet be opened in the browser; ZIP import/export and OPFS storage remain a separate checkpoint to complete before release.

## File ownership

Each save captures the project JSON and its current file references together. Read access protects those files until the save ends. Later captures are included on the next save, and edits during copying keep the project marked as unsaved. Replacing destination copies on every save also handles a deleted file's path being reused for different contents.

`ProjectAssetReferences` retains files for the current model and saved documents. Opening storage discovers files without assigning every file to the project.

Commands explicitly retain the files needed while their nodes are removed, and release their claims when those nodes return or the commands are discarded. Device and track removal capture current plugin state before detaching nodes; a capture failure leaves those nodes in the project.

Saves select only the current model's references. A successful save updates that document's retained references; failed saves preserve its previous references. Save As retains the original document's references as well.

Deletion remains explicit. Garbage collection, recovery discovery, and incremental-copy tracking are deferred until their use cases can be tested through a complete workflow. Preset loads and arbitrary opaque-state undo are separate work; existing device and track undo commands retain the state files of their captured nodes.
