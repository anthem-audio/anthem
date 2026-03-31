# Engine-Side Change Application (Generated C++)

## Scope

This page explains the engine-side half of model sync at a design level: how generated C++ receives model messages, routes them through the model tree, and keeps the engine's mirrored state up to date.

## Runtime Entry Points

Engine-side sync is handled in the model-sync command handler:

- `ModelInitRequest` deserializes the full project JSON into a C++ `Project` tree and runs `initialize(...)` to wire parent/self links.
- `ModelUpdateRequest` is forwarded to the root model's generated `handleModelUpdate(...)`, which applies a targeted in-place change.

`ModelInitRequest` is used when first loading the project model, and `ModelUpdateRequest` is used thereafter.

## Generated C++ Pieces

For synced models, generation produces a few core pieces:

- data classes that can be serialized to and deserialized from JSON via reflect-cpp
- a model wrapper base (`<Model>Base`) that inherits `AnthemModelBase`
- generated `initialize(...)` and `handleModelUpdate(...)` methods
- optional per-field observer helpers

Collections are represented with `AnthemModelVector<T>` and `AnthemModelUnorderedMap<K, V>`, which participate in the same model-tree initialization contract.

## Update Application Model

`handleModelUpdate(...)` is generated as a path-driven dispatcher.

At each step, it:

1. reads the current accessor segment (`fieldName`, and optionally index/key metadata)
2. resolves that segment to a concrete field
3. either applies a value change at this level or forwards to a child model/collection
4. returns early with logs when request shape and field type are incompatible

### Type-Level Behavior

The generator uses different strategies by field category:

- scalar-like fields (primitives/enums/value types): leaf-only replacement
- collection fields (list/map): either structural element operations or whole-field replacement
- model-like fields (custom models/unions): leaf replacement or recursive forwarding into the active child

The important detail is not the exact branch code; it is that every update is interpreted as "apply here" vs "forward deeper", based on accessor depth and field category.

## Message Contract Assumptions

The generated handler assumes:

- `fieldAccesses` is a root-to-leaf path
- each model-level segment identifies a field name
- list/map segments include index/key metadata
- `updateKind` semantics are consistent with the target (for example, list supports insert/remove semantics, map does not support `add` as a separate operation)

When these assumptions are violated, the update is dropped and logged.

## Observability in C++

There are two observer surfaces:

- per-field observers on generated wrappers
- model-level observers on `AnthemModelBase` via `processChange(...)`

Current behavior is coarse. Direct field assignments are surfaced reliably, while deep collection churn and forwarded descendant changes are not exposed with Dart-equivalent event richness.

## Platform Gating and Variants

`skipOnWasm` affects generated C++ structure:

- model files can be omitted from wasm builds
- union branches for wasm-skipped model types are conditionally removed

This keeps desktop-only model types out of wasm targets without changing Dart-side model authoring.

## Extension Pattern for Engine Logic

When engine behavior is needed beyond generated sync mechanics, models can provide:

- `cppBehaviorClassName`
- `cppBehaviorClassIncludePath`

Pattern:

1. generated base owns synchronization and structure
2. hand-written subclass owns domain behavior/side effects

This separation keeps sync rules centralized while preserving extension points for engine features.

## Error Handling Approach

Generated handlers are defensive. Invalid or incomplete updates are rejected with logging (missing access metadata, bad JSON for the target type, invalid update-kind/field combinations, etc.), and handling returns early for that path.

The design preference is safety over partial best-effort mutation.

## Source References

- [`codegen/lib/generators/cpp/cpp_model_sync.dart`](/codegen/lib/generators/cpp/cpp_model_sync.dart)
- [`codegen/lib/generators/cpp/cpp_model_builder.dart`](/codegen/lib/generators/cpp/cpp_model_builder.dart)
- [`codegen/lib/generators/cpp/get_cpp_type.dart`](/codegen/lib/generators/cpp/get_cpp_type.dart)
- [`engine/src/modules/command_handlers/model_sync_command_handler.cpp`](/engine/src/modules/command_handlers/model_sync_command_handler.cpp)
- [`engine/src/modules/codegen_helpers/anthem_model_base.h`](/engine/src/modules/codegen_helpers/anthem_model_base.h)
- [`engine/src/modules/codegen_helpers/anthem_model_vector.h`](/engine/src/modules/codegen_helpers/anthem_model_vector.h)
- [`engine/src/modules/codegen_helpers/anthem_model_unordered_map.h`](/engine/src/modules/codegen_helpers/anthem_model_unordered_map.h)
- [`engine/src/modules/codegen_helpers/observability_helpers.h`](/engine/src/modules/codegen_helpers/observability_helpers.h)
- [`engine/src/generated/lib/model/project.h`](/engine/src/generated/lib/model/project.h)
- [`engine/src/generated/lib/model/project.cpp`](/engine/src/generated/lib/model/project.cpp)
- [`engine/src/generated/lib/model/processing_graph/node.cpp`](/engine/src/generated/lib/model/processing_graph/node.cpp)
