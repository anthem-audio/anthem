# Codegen Overview

## Purpose

Anthem runs a Dart UI and a C++ engine in separate processes, and both need a consistent view of model and message data. The `codegen/` module is the source-of-truth bridge that turns annotated Dart definitions into generated Dart and C++ code so this consistency can be maintained without hand-writing parallel model and messaging implementations.

At a high level, codegen does three things: it generates Dart serialization/deserialization and model change APIs, generates matching C++ models for engine-side decoding and runtime use, and generates model synchronization handlers so granular UI-side model changes can be forwarded and applied in the engine.

There are two categories of classes that interact with this generator: project model classes (`lib/model/`), and IPC messaging classes (`lib/engine_api/messages/`). These two model types share many things in common, in that the same base codegen system creates C++ classes to represent both types of Dart classes, and class instances can be serialized and deserialized on both sides. However, there are two primary differences to note:

1. IPC messages use a special-case structure, where the base request and response types are defined as sealed classes in Dart, and all messages or responses subclass from this base type. This system is special to IPC messages, and **does not work** for project model classes. Furthermore, project model classes cannot extend other classes in any way (the `@Union()` annotation can be used instead for polymorphism in project models).
2. Classes tagged as model classes (via the `@AnthemModel.syncedModel()` annotation) will generate sync code. IPC message classes do not need this capability, but they also do not support it due to their structure.

## Structure

- `codegen/lib/include/`: Public annotations and runtime helpers consumed by model code and generated code.
- `codegen/lib/generators/dart/`: Dart source generation for mixins (`toJson`, `fromJson`, MobX-aware accessors, model change listeners/filter builders).
- `codegen/lib/generators/cpp/`: C++ source generation for enums, model structs/wrappers, module headers, and model sync handlers.
- `codegen/lib/generators/util/`: Shared analyzer/type parsing and code-writing utilities.
- `codegen/test/`: Behavior tests for serialization, sealed-class support, model change events, and listener filter logic.
- `codegen/build.yaml`: Builder registration and output extension configuration.

## Overview

### Source model structure

For project model classes and IPC message classes, authors define Dart classes and annotate them from `anthem_codegen/include.dart`. At a high level, codegen expects a generated-mixin pattern (public class + base class), and uses those annotated Dart definitions as the single source of truth for both generated Dart and generated C++ representations.

Project model classes and IPC message classes share this shared source-of-truth pipeline, but differ in behavior:

1. Project model classes (`@AnthemModel.syncedModel()`) generate model synchronization constructs.
2. IPC classes generate serialization and matching C++ types, but do not generate model sync behavior.

### Generated Dart constructs

For annotated classes, the Dart generators produce:

1. JSON serialization/deserialization methods (`toJson` / `fromJson`), including support for nested models, collections, enums, unions, and sealed-class metadata where applicable.
2. Generated accessors and MobX integration code for fields that need observability and/or sync-aware mutation behavior.
3. Model change event constructs for synced models, including field/list/map operation reporting and typed `onChange` filter builder APIs.
4. Parent/child wiring helpers so nested model structures can propagate changes upward through the model tree.

### Generated C++ constructs

The C++ generators emit engine-side artifacts under `engine/src/generated/`, including:

1. C++ enums and model types that mirror the annotated Dart definitions.
2. Optional wrapper/behavior-class integration where configured by annotation options.
3. Model-update handlers (for synced models) that can apply incremental updates using accessor paths and update operations.
4. Module headers (for libraries marked with `@GenerateCppModuleFile`) that centralize generated includes for larger model surfaces.

### Runtime synchronization shape

Once generated code is in place, runtime behavior follows this high-level shape:

1. UI-side Dart models are authoritative. Changes only ever flow from Dart to C++, not the other way around.
2. Full model/message payloads are serialized/deserialized through generated `toJson`/`fromJson` code.
3. For synced models, Dart-side mutations emit structured change events (field accessor chain + operation payload).
4. Engine-side generated handlers consume those update messages and apply changes to the mirrored C++ model.
5. The result is snapshot compatibility plus incremental synchronization: complete transfer when needed, targeted updates during normal editing.
