# Graph Model for Audio Processing

Anthem uses a node graph to route audio, control and note data between plugins and through to a master audio output node. This graph has two components: nodes and connections. Nodes can take zero or more inputs and produce zero or more outputs in three different data types: events (note on, note off, etc.), audio samples, and audio-rate control values.

Processors in Anthem are defined as nodes in this graph. Processors can take inputs in any of the three data types, define processing routines for operating on these inputs and/or synthesizing new data, and produce outputs in any of the three data types.

Connections can be defined from any input to any output of the same data type. Anthem's processing graph module is responsible for transporting data along connections in the graph, and for calling the processing routines on processors in the graph.

## Processor initialization and port discovery

When a device is added, Anthem creates a node in the Dart project model to represent it. The node records which processor to use, any explicit creation overrides, and stable port IDs used for routing. The engine supplies the processor's initial state and descriptions. Opening a project reconstructs cached descriptions, values and routing from the project file.

Each node has a non-nullable, write-once processor reference. Changing processor type or instance requires replacing the whole node; modifying the processor's state does not.

The engine still needs to load and prepare the processor before it can process audio. It also needs to establish which ports exist and how many channels each audio port has. A saved port description may no longer match the installed plugin, and channel counts can depend on the active audio configuration. For example, the project can contain a connection to the master output before the engine knows whether the output device has two or four channels. An unprepared processor is omitted from the runtime graph's processing pointer, preserving the existing unavailable-plugin behavior.

Processor initialization happens before the graph is compiled and sent to the audio thread. It gives the UI the current port descriptions and base parameter values after applying creation settings or restoring a snapshot.

### Parameter ownership and saved settings

The engine owns each processor's base parameter values. These are the editable settings that Anthem preserves while automation controls the values used for processing. Both native processors and plugin hosts use the same parameter storage and editing API. Parameter storage belongs to the processor instance and survives graph recompilation.

For a new processor, the engine initializes its own factory state. The application may supply one-time overrides in `NodeModel.initialParameterValues`. A regular track's utility processor, for example, starts with its gain at −10 dB instead of the processor's unity-gain default. The engine applies overrides during initialization when no saved snapshot exists. They remain on the node until the first state snapshot is retained, so a restart before that capture can still create the processor with the intended settings. Creation overrides are independent of preset save/load and do not implicitly change reset targets.

Processor snapshots contain the base parameter values and any additional processor-specific state. A VST's private payload comes from JUCE and can include settings that Anthem cannot describe as parameters. Native processors currently need only the common parameter data. The engine writes snapshots to the project asset store; opaque bytes do not pass through the Dart model or IPC.

`NodeModel.processorStateRetentionId` identifies a retention claim on a snapshot file. The asset store exports project-owned claims as a JSON string saved in `ProjectModel.fileRetentions`. Engine storage requests resolve the retention when they need the file. Identical snapshots reuse the previous file path using a cached content fingerprint. A VST's opaque payload may include automated values, so captures at different playback positions can still produce different bytes even when the base settings have not changed.

`NodePortModel.parameterValue` is the UI's last confirmed base value. It remains MobX-observable and can be saved as a preview, but it is excluded from engine model synchronization. Controls send edits through the engine API and display a pending value while waiting for confirmation. The response updates the observable cache with the accepted value. A rejected request clears its pending value. Undo records accepted changes, including the earlier part of a drag whose final request was rejected. Effective automation values use the visualization channel.

### Plugin change reporting

JUCE can call plugin listeners on processing, editor or other plugin threads. VST3 callbacks use a table of direct parameter pointers built during initial preparation and retained unchanged until the plugin is destroyed. Ordinary metadata refreshes and re-preparation reuse those bindings; a changed parameter layout requires reloading the plugin. Parameter changes update the processor's atomic base values immediately, so state capture does not depend on notification delivery. Callback operations do not allocate, post JUCE messages or change shared ownership; their atomics must be lock-free. A message-thread timer drains notifications, formats parameter text and sends IPC. Gesture boundaries carry their captured values so a complete gesture between timer ticks still produces the correct undo command.

Notifications use `RecoverableNotificationQueue`, which wraps the existing single-writer ring buffer. Each callback makes one atomic attempt to claim the writer; if it is busy or the buffer is full, the callback requests recovery and returns without waiting or retrying. Recovery discards stale notifications, sends current values and clears unfinished UI gestures for that node. Intermediate undo history can be lost during recovery, but parameter state is retained. Callbacks overlapping a recovery request another snapshot so their changes are not lost behind the recovery snapshot.

### Pausing node processing

`GraphProcessor::pauseNode` asynchronously supplies a `NodeProcessingPause` claim once the processor is no longer in use by processing threads. Its callback runs on the message thread. Independent claims can overlap; the node resumes only after every claim is released or destroyed. Claim ownership and release belong on the message thread. `GraphProcessor` tracks pause requests and holds a reference to the engine's current project pointer. It looks up nodes directly on the message thread, including after project replacement.

The pause gate belongs to the processor instance and survives replacement of compiled graphs. A single lock-free atomic coordinates access and pause requests. `rt_tryAcquireProcessingAccess()` checks availability and reserves access; it does not perform DSP. After using the processor, `rt_releaseProcessingAccess()` releases that access. If access was acquired first, pause acknowledgement waits for its release. If the pause request arrived first, acquiring access fails immediately. An already-idle processor needs no additional audio callback to acknowledge suspension. Releasing the last pause claim permits access again without requiring a separate resume acknowledgement. Processing threads never wait, allocate, post messages, or change shared ownership for this protocol.

The executor clears a paused node's audio and control outputs and empties its event outputs, then completes ordinary scheduling and buffer-release bookkeeping. It does not invoke the processor. Downstream and disconnected nodes continue to run. The master output is a special endpoint and cannot be paused; its configuration changes through audio-session stop/start coordination. It continues processing while upstream nodes are paused, so output readers use its buffer normally.

`GraphProcessor` polls acknowledgements and node identity on the message thread. Removing or replacing a node cancels its pending requests and invalidates its delivered claims. Runtime graphs retain their source nodes until message-thread retirement, which also keeps their processor instances alive. Removed nodes stay stopped while an older runtime graph still refers to them.

Final graph-processor shutdown stops pause polling and cancels pending requests and held claims. Clearing a runtime graph preserves pause claims. Audio-session shutdown needs no extra handshake: after the last processing call exits, a pending pause can complete without another block, and held claims remain valid across audio-session restart.

Live snapshot loading uses this suspension primitive. Snapshot ownership, state replacement, undo, and presets remain separate concerns.

### Restoring a processor before reporting its ports

For a processor with a saved snapshot, initialization runs in this order:

1. Create and prepare the processor, establishing its parameter storage and provisional port descriptions.
2. Resolve `processorStateRetentionId`, read the snapshot, and restore its processor-specific payload followed by its base parameter values.
3. Prepare the processor again, since restoration may have changed its audio bus layout.
4. Return the final port descriptions and base parameter values to the UI.

This sequence finishes before the processor is published for audio processing. A new processor without a snapshot receives its explicit creation settings after the first preparation. Initial restoration needs no suspension handshake.

Saved state is restored once for each processor instance. If the audio session restarts with a different sample rate or buffer size, the existing processor is prepared again and keeps its live settings. A fresh engine process creates new processors and restores the latest retained snapshots. Cached UI values are never replayed as processor state.

Anthem captures state only after initialization succeeds. If a processor cannot load, saving preserves its previous state-file reference. See [the initialization session](../../engine/src/modules/core/processing_graph_node_initialization_session.cpp) for the engine implementation.

### Retained snapshots and live replacement

`ProcessingGraphController.saveSnapshot(nodeId)` returns a `ProcessorSnapshot`. The caller owns its retention and releases it with `dispose()`. Saving does not change the node's project-owned snapshot reference. The handle remains usable across engine restarts while its project stays open. It currently belongs to the same processor model instance; preset identity and interchange are later layers.

The engine's save response hands its retention token to the UI; the engine must not use or release that token afterward. The UI calls `adoptReturnedFileRetention` to replace the temporary engine-session claim with a caller-owned retention. If the response is never received or adopted, engine-session cleanup releases the temporary claim. Call this helper only for tokens explicitly handed to the UI; it must not revoke claims still in use by the engine.

`loadSnapshot(nodeId, snapshot)` borrows the handle and can be called repeatedly. It acquires its own claim before waiting, so the caller can dispose its handle while loading. Opaque state stays in files and never crosses IPC.

`replaceSnapshot(nodeId, snapshot)` performs the same load and returns an independently owned handle to the previous state. It reuses the recovery snapshot already captured inside the load operation, so capture and replacement share one queue turn. Callers dispose that handle when finished. `loadSnapshot` is the convenience form that disposes it automatically. `ProcessorSnapshot.retain()` creates another independently owned handle to the same file without copying its bytes.

For an undoable load, execute a `LoadProcessorSnapshotCommand` through the project:

```dart
await project.execute(
  LoadProcessorSnapshotCommand(nodeId: nodeId, snapshot: snapshot),
);
```

The command retains its target at construction, so the caller can dispose its handle independently. On first execution, it keeps the previous state returned by `replaceSnapshot`; undo loads that state and redo loads the original target. Removing the command from history releases both handles. The node's current project-owned state remains independently retained. Failed execution does not add a history entry; failed undo or redo keeps its position for retry. Recovery and engine synchronization remain in the controller.

Live loading proceeds as follows:

1. Save a fresh recovery snapshot and adopt it as the node's project-owned saved state. Failure or engine loss after this point preserves the pre-load state for restart.
2. Resolve and validate both files, then wait for the node's processing pause. Disable processor notifications while restoring state and preparing its current ports.
3. Return the port descriptions and base values. Dart applies them using the same reconciliation and routing path as initialization.
4. Publish the reconciled runtime graph. The engine holds the pause until the audio thread acknowledges that publication, then resumes the node. An idle offline session has no processing thread; its first render block adopts the pending graph before processing.
5. Replace the project's recovery reference with a claim on the requested snapshot. The caller's original claim remains independent.

A restoration or preparation failure attempts to restore the recovery file and reconcile its ports before resuming, then reports the original error. A reconciliation or publication failure also attempts recovery. If processor recovery fails, the node stays unavailable and paused; restart the engine to restore its retained recovery file. If the UI cannot confirm recovery or a load times out, it stops the engine session so an ambiguous completion cannot leave it processing unconfirmed state. Invalid input files fail before the processor is changed. Removal, audio-session changes, shutdown and timeouts interrupt pending loads rather than resume an unconfirmed configuration.

`ProcessingGraphController` is a project-scoped service owned by `ServiceRegistry`. It serializes complete publication and state workflows in one FIFO queue. A publication includes node initialization, applying discovered descriptions and routing, and submitting the compiled graph. A state load holds its turn through recovery capture, restoration, model reconciliation, graph activation and resume. Project captures and explicit snapshot saves use the same queue. Offline rendering owns one queue turn through audio-session setup, rendering and restoration; its internal publications run within that turn, so render request holds cannot block preceding graph work. Inner steps call the engine API directly; they do not queue work behind the operation that is awaiting them.

Adjacent queued publication requests coalesce, but requests separated by a state operation keep their order. Model edits still synchronize immediately when the engine is running. Offline edits need no publication; engine startup synchronizes and publishes the current project. Engine shutdown and engine-to-UI file-service replies do not wait for this queue. Queued work is tied to its original engine session and cannot run against a restarted engine. A failed operation releases the queue for subsequent work. Callers use `ProcessingGraphController.publish()` directly; `ProcessingGraphApi` provides the individual protocol requests.

State operations wait for outstanding parameter edits, and explicit snapshot saves/loads reject new edits while active. Finish any active parameter gesture before loading. Ordinary project captures share that serialization. Save/load and active offline rendering exclude each other so a temporary pause cannot alter a render's output.

`NodeModel.canEditParameters` and `canHandleProcessorEvents` express the node’s runtime policy. Controls and parameter controllers share the editing policy. Unsolicited processor events inherit `ProcessorEvent`, carrying a node ID; `ProjectEngineEventHandler` resolves the node and checks its event policy once before dispatch. Snapshot capture permits these events, while restoration suppresses them. Explicit initialization and state-load responses apply their results directly, and node removal remains available.

VST restoration uses JUCE's existing message-thread state and restart handling, followed by preparation and port discovery. Audio bus layouts can change during restoration. The stable parameter-binding contract still applies: a changed VST parameter list requires reloading the plugin. JUCE does not reliably expose a plugin's internal refusal to restore state; Anthem can report exceptions and preparation failures, but cannot detect a plugin that silently ignores its state.

### Updating cached port descriptions

Both native processors and VSTs return port descriptions through the same initialization response. Native C++ processors declare their ports in `prepareToProcess`. VST processors obtain their descriptions from JUCE. The response includes port names, audio channel counts, and parameter factory defaults and formatting information.

Native factories supply stable routing endpoints without duplicating parameter defaults or formatting. These ports start with `isAvailable` set to false and have no discovered channel counts or parameter descriptions. Known routing can be recorded before discovery; graph compilation uses confirmed endpoints. New controls wait for reported values, while opened projects can display their saved descriptions and last-confirmed values even when the engine is unavailable. This does not introduce a separate offline parameter-editing path.

When the response arrives, `NodeModel.applyPortConfiguration` matches existing ports by ID. Every reported port goes through `NodePortModel.applyConfiguration`, which updates descriptions in place, including visual baselines. New and existing ports use the same metadata-update path. Existing configuration objects, values, reset overrides and connections are preserved. Newly reported ports are added. A factory default can fill an empty UI preview while initialization is pending. The engine then reports the confirmed base values for both native processors and plugin hosts.

Port additions, availability changes, type corrections and reordering trigger a refresh of device defaults and routing. Metadata-only changes, such as a new name or visual baseline, update the cached descriptions without rebuilding routing. Repeated identical reports leave the models and connections unchanged.

Port IDs, parameter meanings and normalized value mappings must remain compatible across software versions. An incompatible native successor needs a new processor identity, with the old processor retained as legacy. Runtime channel counts may still vary. Native IDs are defined as constants in the private Dart processor model class and exported to C++ through model codegen. See [model constants](../codegen/project_models/authoring_and_annotations.md#constants-are-supported).

### Parameter values, defaults and visual settings

A parameter's current value and its default are separate. Anthem also allows a project to choose a reset value that differs from the processor's factory default. For example, the utility processor's factory gain is 0 dB, while a regular track's utility starts at −10 dB and resets to −10 dB.

The model stores these values separately:

| Field | Purpose |
| --- | --- |
| `NodePortModel.parameterValue` | The last base value confirmed by the engine, cached for display. |
| `NodePortModel.pendingParameterValue` | A requested base value displayed while an edit awaits confirmation. |
| `ParameterConfigModel.factoryDefaultValue` | The processor's own default, reported by the engine. |
| `NodePortModel.parameterResetValue` | An optional project-specific reset value. If absent, reset uses the factory default when known. |
| `ParameterConfigModel.normalizedVisualBaseline` | The processor-reported value from which knob arcs and automation shading extend. |

Port names and channel counts belong to `NodePortConfigModel`, which also holds the parameter configuration. Visual baselines are processor metadata: native pan parameters report 0.5 so knob arcs and automation shading extend from the center. The project caches these descriptions for display without the engine. Explicit reset targets remain project choices, independent of factory defaults and visual baselines.

## Unavailable ports and saved routing

Anthem keeps unavailable ports in the project, together with their parameter values, visual settings and connections.

Each port has an `isAvailable` flag. Initialization sets it to true for ports reported by the engine and false for ports that are missing. The flag is sent to the engine but is not saved in project files: reopening a project requires the engine to confirm its ports again. Reported ports appear first in the node's lists, in engine order, followed by missing ports in their previous order.

For example, if a synth was connected to an effect whose input is now missing, that connection remains saved. When publishing the graph, the engine excludes it because both ports must be available for a connection to carry data. If the input returns, a later publication includes the connection again. Explicitly deleting a node or connection still removes it from the project.

The engine collects usable connections once during graph compilation. It uses them to determine processing order, allocate buffers and build data transfers between processors. The audio thread receives the compiled result and does not check saved connections for availability during playback.

Device rack connections are generated from device order and each device's default-port references. `DeviceController.rebuildTrackDeviceRouting` removes and recreates all of those generated connections, using cached ports even when they are unavailable. In the synth/effect example, rebuilding still connects the synth to the effect's cached input; it does not bypass the effect because the input is missing. The new connections have new IDs, and graph compilation decides whether they are usable.

Project files store the graph's connections and each port's list of connection IDs. Graph mutation methods update both together. `fromJson` reads those records as stored, assuming they are consistent.

## Project file compatibility

Loading a file saved by an older Anthem version requires a migration before constructing the model. The project loading workflow calls [`migrateProjectJson`](../../lib/logic/project_file/migrations/migrate_project_json.dart) to bring the JSON into the current format. Model `fromJson` methods then read that format without converting older schemas.

For standalone prealpha.1 files, the migration writes common snapshots containing saved parameter values and any embedded plugin state into a temporary directory. It replaces the JSON blobs with retention IDs and a serialized map of those IDs to relative file paths. It uses the historical format directly, before the current model or asset store exists. After migration, normal project storage opens the prepared directory. A failed import deletes that directory and preserves the original file.

The `prealpha.2` migration preserves the old parameter defaults as project reset values and retains visual baselines in the cached parameter descriptions. For native processors, it clears the old factory defaults so the engine can supply them during initialization. Existing parameter values are preserved.

## Pre-calculating processing steps

The processing graph is stored in the main thread and compiled into a set of parallelizable processing instructions. When the graph topology is updated, these instructions are recompiled and pushed to the audio thread, at which point the audio thread releases its old instructions and allows them to be deallocated by the main thread.

This is done for two reasons. First, it is non-trivial to traverse this graph. Pre-computing the processing instructions on the main thread saves the audio thread a lot of work. Second, pre-processing these steps opens the door to a fully generic multithreaded solution to audio processing in the future.

## Plugin delay compensation

Plugin delay compensation (PDC) is a feature that allows processing delay in plugins to be corrected by the DAW. Some types of effects, such as EQ, filters and multiband processors, introduce delay into the signal by necessity due to how they perform their processing.

For example, if an audio engineer wants to mix the dry and wet signals of a plugin that introduces delay, the mixed signal will contain phasing artifacts due to the mismatched delay. With PDC, these artifacts will not be present.

Anthem's processing graph does not yet support this.

## Audio

Nodes in the processing graph can generate and consume audio streams. One audio output can go to multiple inputs, and multiple outputs can go to the same input. When multiple audio streams are routed into the same port, they are summed together additively before being given to the corresponding processor to process.

Consider the following graph:

```
 ________________       ____________________________
| SourceNode1    |     | Processor1                 |
|   AudioOutput1----.----AudioInput1   AudioOutput1--- ...
|________________|  |  |____________________________|
                    |
 ________________   |
| SourceNode2    |  |
|   AudioOutput1----*
|________________|
```

Each input port (in this case, just a single input) contains a buffer that is the same length as the block size, plus (in the future) an amount to account for any plugin delay compensation that is needed.

The compiler will produce the following steps for this graph:

1. Write zeros to the `AudioInput1` buffer on `Processor1`
2. Run the process method on `SourceNode1`, which will generate an output on its `AudioOutput1` buffer
3. Add the result of `SourceNode1`'s `AudioOutput1` buffer to the `AudioInput1` buffer on `Processor1`, and write this result back to the `AudioInput1` buffer
4. Same as step 2, but for `SourceNode2`
5. Same as step 3, but for `SourceNode2`

## Control values

Control values function in a very similar way to audio, in that they are represented as audio-rate streams of floating point values. There are, however, a few key differences:

1. Control values are always represented as a floating point between 0 and 1. This should represent the full parameter range, and there should not be any values beyond this range.

2. Control values are not summed additively. If a control input port has multiple connections, the most recent connection takes priority.

### Parameters

In Anthem, all control inputs on nodes also function as parameters. Parameters augment control input ports by allowing the port to be given a constant numerical value to use instead of control input.

If a control input port has a connection, the control values that come through on that connection will always override the static parameter value. Otherwise, the control input will take on the static value provided through the parameter.

Editing the base value preserves that setting for when control disconnects. An active control connection continues to determine the effective value used for processing.

## Events

Similar to the above data types, processors in Anthem can receive and output events. The most common of these events are note events. Notes coming from the sequencer may be sent directly to an instrument, or they may be transformed by another processor first.

<!-- ## Unique challenges -->

<!-- Must the graph always be acyclic? It seems good to do this for audio, but what about the output of a peak controller? -->
