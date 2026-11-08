# Rust model and message snapshots

The Rust engine's project types are generated from the same Dart definitions as
the C++ model. Run `dart run anthem:cli codegen generate --root-only` before
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
These types can coexist in the same aggregate module. Lists and maps own their
contents. Cloning a model handle shares that instance; loading JSON creates a
fresh tree.
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

This checkpoint covers data and serialization. Incremental project updates,
observers, behavior lifecycle, and project service installation follow in later
checkpoints.

## Compatibility tests

`flutter test test/codegen` checks committed JSON fixtures against the Dart
serializer, including a complete new project, messages in all three roles, and
models with additional serialization and inheritance cases. Run the Rust checks with
`cargo test --manifest-path engine-rust/Cargo.toml --locked`; they load those
fixtures using the generated types, verify typed access, and compare serialized
JSON values. A codegen integration test also checks that changing an imported
Dart model invalidates and regenerates its aggregate Rust output.

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
