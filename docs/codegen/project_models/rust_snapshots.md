# Rust model and message snapshots

The engine's project types are generated from annotated Dart definitions.
Run `dart run anthem:cli codegen generate --root-only` before
building or testing the Rust engine. Generated Rust files live under
`engine-rust/src/generated/` and are ignored by Git.

`@GenerateRustModels([ProjectModel])` on `lib/model/model.dart` selects the roots.
The builder follows their engine-visible fields transitively, so adding a child
model does not require another Rust registration. With no roots specified,
`@GenerateRustModels()` selects all serializable Anthem model classes in the
annotated library, including its parts. Both forms follow field dependencies.
Existing `@hideFromCpp` fields remain excluded, and `skipOnWasm` excludes
desktop-only types and union variants from Emscripten builds.

Generated structs expose read accessors and derive Serde serialization and
deserialization. Each class's existing `generateModelSync` setting controls its
Rust representation. Synced models have private fields, and references to them
use `ModelRef<T>`, backed by `Rc<RefCell<T>>`, with scoped reads through `with(...)`.
Ordinary serializable classes have public fields and are stored as owned values.
These types can coexist in the same aggregate module. Synced fields use
`ModelList<T>` and `ModelMap<K, V>`, which own their contents and expose read-only
access to them. Nested collections use the same wrappers at every level.
Ordinary payload collections remain `Vec` and `HashMap`. Cloning a model handle
shares that instance; loading JSON creates a fresh tree.
Generated fields and accessors use raw identifiers (`r#type`, for example), so
Rust handles keyword recognition. Ordinary names can still be called normally.

The Rust library groups engine startup, the message thread, and services under
`core`, project types and their support under `model`, and IPC types under
`messages`. Generated files are re-exported through these modules; their disk
paths do not appear in application imports. The executable calls `core::run()`
so all engine code uses the library's runtime and service registry.

JSON preserves Dart field names, enum names, externally tagged unions, omitted
nullable fields, byte-based color channels, and string-encoded map keys. Dart
`int` maps to Rust `i64`, `double` to `f64`, and `num` to `serde_json::Number` so
integer and floating-point representations are retained. Maps currently support
non-null string, integer, boolean, and enum keys. Unsupported field types and
name collisions fail generation with an error.

## Message types

`@GenerateRustModels()` on `messages.dart` generates its annotated serializable
classes, including `IpcMessage`, `Request`, `Response`, `IpcEvent`, and payload
records. They are exposed through `anthem_engine::messages`. Sealed classes become enums with struct variants,
preserving Dart's `__type` discriminator and flattening inherited fields:

```rust
let request = anthem_engine::messages::Request::Heartbeat { id: 42 };
```

Message payload records have public fields and use owned values, so messages
can be constructed directly and sent between threads. Request and response
enums expose their inherited `id()` accessor. Project model handles retain
their shared, message-thread-only ownership.

## Model synchronization

Generated synced models implement `ModelValue`: a field-name dispatcher that
forwards the remaining update path to the selected field. Collections handle
their own insertion, replacement, removal, and recursive forwarding. Primitives
accept leaf replacements, optional values forward through `Some`, and unions
forward into their active variant. Nested traversal does not replace existing
model handles; replacing a model creates a new instance.

The existing `ModelInitRequest`, `ModelUpdateRequest`, and
`GetSerializedModelFromEngineRequest` messages are handled by
`core::model_sync::handle_request` on the message thread. `EngineRuntime` installs
a stable project slot in the service registry; `with_project(...)` provides
scoped read access to the current project. The `Application` service owns
application lifecycle operations on that thread: `shutdown()` requests ordinary
shutdown, and `report_fatal_error(...)` preserves the first failure and stops
the runtime before another queued job is dispatched. Any subsystem can look up
this service through `services::with::<Application, _>(...)`.
`EngineRuntime::run()` returns the resulting `EngineFailure`. Sync errors retain
their request and path context.

The generator and runtime mark the update phases with comments. Replacement
values are decoded, mutation is performed, and removed subtrees are retained in
`ModelChange` while recursive model borrows unwind. The runtime then calls
`finish()` to release those values after all model borrows have ended. Future
removal hooks, initialization hooks, and field observers belong at that same
boundary, in that order, before another request is processed. Behavior support
and its lifecycle hooks are not implemented yet.

`ModelUpdateRequest.fromChange(...)` converts Dart model changes into engine
update requests. The project's change listener and the compatibility fixtures
call this constructor. Strings and string keys are JSON encoded, including
escapes. Nullable union setters accept `null` and emit a normal replacement
message.

The standalone engine still has no IPC transport. Its executable and the
runtime test use the same `EngineRuntime`; the test supplies work through the
existing message-thread queue, without a separate engine application or test
startup mode.

## Compatibility tests

`flutter test test/codegen` checks committed JSON fixtures against the Dart
serializer, including a complete new project, messages in all three roles, and
models with additional serialization and inheritance cases. Run the Rust checks with
`cargo test --manifest-path engine-rust/Cargo.toml --locked`; they load those
fixtures using the generated types, verify typed access, and compare serialized
JSON values. A codegen integration test also checks that changing an imported
Dart model invalidates and regenerates its aggregate Rust output.

The sync fixture captures real Dart project edits and an additional nested
`List<Map<String, List<Model>>>` model using that production encoder. Rust tests
replay the project requests from a worker thread through `EngineRuntime`, query
the installed model, and compare complete project JSON. They also compare the
nested model after every update, exercise invalid updates, and verify fatal
shutdown from sync and other subsystems with later jobs already queued. This
covers the runtime and model
pipeline in process; it does not exercise a UI or IPC connection.

After an intentional fixture change, regenerate the JSON using PowerShell:

```powershell
$env:ANTHEM_UPDATE_RUST_FIXTURES = '1'
flutter test test/codegen
Remove-Item Env:ANTHEM_UPDATE_RUST_FIXTURES
```

On Bash:

```sh
ANTHEM_UPDATE_RUST_FIXTURES=1 flutter test test/codegen
```

CI checks both Dart fixtures and native Rust tests, then builds the project
models with the pinned threaded Emscripten toolchain.
