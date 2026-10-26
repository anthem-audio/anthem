# Processor state storage investigation

Investigated on 2026-10-09. This records findings and decisions for future work. Desktop file storage, engine storage requests, folder-based project save/load, and file-backed VST state are implemented. Preset operations are next.

## Scope

Investigate a common state capture, restoration and preset mechanism for native,
VST3 and future CLAP processors, without requiring large opaque state to pass
through the Dart project model and ordinary model synchronization.

Native sample/wavetable asset management, immutable assets and small snapshots
that reference those assets are **deferred until there is a specific use-case**.
Do not introduce that machinery as part of this investigation. Likewise, do not
require a database, chunk deduplication or a new native state framework up front.

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

`NodeModel.processorStateRetentionId` identifies a project-owned claim on an opaque binary file in the `plugin states` category. The asset store exports the project scope’s retention IDs and relative paths as a JSON string in `ProjectModel.fileRetentions`; commands and saved documents retain independent runtime claims. Commands replace node claims with their own during removal and create new project claims on restoration. JUCE supplies the bytes through `getStateInformation`; restoring them uses `setStateInformation`. Saved control-port values are UI mirrors, rather than an additional source replayed over restored plugin state.

The engine obtains write access from the UI, writes and closes the file, and commits it before returning its relative path. Unchanged captures reuse the previous file after comparing byte length and SHA-256 against the asset store's cached fingerprint. Capture failures leave the previous model reference intact. Initialization obtains read access to the saved file, restores it, then prepares the plugin again before reporting final ports and values. Audio-session re-preparation does not replay saved state over live edits.

State capture is debounced after plugin changes and also occurs before saving. Only file references travel through ordinary IPC and model synchronization. JUCE still allocates a complete `MemoryBlock` during capture and restoration; this implementation does not provide VST stream-based capture or eliminate that engine-side allocation. The engine obtains file access before capturing state. Capture, hashing and writing run synchronously on the message thread, and the complete buffer is released before waiting for commit or access-release replies. Callers can submit captures together without retaining complete buffers across those waits.

Prealpha.1 imports extract their embedded JUCE-encoded state into a temporary directory using migration-local file writes. The migration updates the raw JSON before the current model and project storage are constructed. That legacy import necessarily decodes the old payload in Dart. Current-format projects contain only file references.

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

The previous embedded-state path used two base64 layers:

1. JUCE captures component and controller state in memory, encodes each as base64 inside XML, then writes the XML into a `MemoryBlock`.
2. Anthem encoded that block again for its JSON response and retained the result in Dart, including incremental model synchronization.

Ignoring XML overhead and additional controller state, two base64 layers expand the original VST state by approximately `(4 / 3)^2`, or **1.78 times**. This is an encoding-size calculation, not a measured peak-memory figure. The file-backed path removes the outer Anthem encoding, the payload in Dart, and its IPC transfers. JUCE's internal encoding remains.

See [JUCE's VST3 wrapper](engine/include/JUCE/modules/juce_audio_processors_headless/format_types/juce_VST3PluginFormatImpl.h) (`getStateInformation` and `appendStateFrom`) and [Anthem's state storage](engine/src/modules/core/processor_state_storage.cpp).

Desktop project saving streams JSON into gzip. Plugin capture now writes state files directly in the engine. A capture buffer exists only during the synchronous capture/hash/write operation; pending IPC replies retain metadata rather than opaque bytes. In the Linux integration fixture, a 1 MiB plugin payload produced a 1,398,406-byte JUCE state file alongside a 1,778-byte project document. These are file sizes, not memory measurements. [Controlled fixture](engine/test_plugins/test_plugin.cpp), [persistence scenario](integration_test/plugin_test.dart).

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

Stages 1 and 2 provide desktop file storage and engine access through IPC. Stage 3 introduces folder projects, then connects processor-state capture and restoration to this store. Folder save/load and file-backed VST snapshots are implemented; preset operations and undoable state restoration are next.

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
