# Dart Sync Runtime (`AnthemModelBase` and Collections)

## Scope

This page documents the **Dart-side runtime** that powers project model synchronization:

- `AnthemModelBase` tree/attachment behavior
- change propagation through model parents
- collection behavior in `AnthemObservableList` and `AnthemObservableMap`
- the MobX "observe all changes" integration helpers

This page is about runtime mechanics after generation. Annotation semantics and authoring rules are covered in [`authoring_and_annotations.md`](./authoring_and_annotations.md).

## Runtime Model: A Tree of `AnthemModelBase` Nodes

All synced project model classes mix in `AnthemModelBase`, and together form a model tree rooted at `ProjectModel`.

Each node tracks where it lives in its parent via:

- `parent`
- `parentFieldType` (`raw`, `list`, or `map`)
- `parentFieldName`
- `parentListIndex`
- `parentMapKey`

When a field is changed, the code-generated setter propagates a message up the tree to `parent`, containing this metadata. That parent then sends a message to its `parent`, appending its own metadata, and so on. The root node (`ProjectModel`) receives all these messages, which now carry a list of metadata objects (`FieldAccessor`) that collectively form a path from the root `ProjectModel` to the specific field in the leaf node that was changed.

Note that this also applies to mutations to collections. All possible mutations (field changes, collection mutations) can be described by the `FieldOperation` carried inside each `ModelChangeEvent`.

## Attachment Lifecycle

### `setParentProperties(...)`

When a model/collection field is assigned, generated code (or runtime collections) calls `setParentProperties(...)` on the child. This does three things:

1. stores parent/location metadata
2. recursively attaches descendants via `setParentPropertiesOnChildren()`
3. runs queued `onModelFirstAttached(...)` callbacks in a microtask

The `onModelFirstAttached(...)` actions are run in a microtask specifically for deserialization. Without the microtask, callbacks will be called at some point in the middle of deserialization, when the current model state is not valid. Running these actions in a microtask delays their execution until the model is fully initialized.

### `setParentPropertiesOnChildren()`

This is abstract in `AnthemModelBase` and implemented by generated code for model classes and by the collection classes.

Purpose: after a node is attached, ensure all children also have correct parent metadata.

For `@hideFromCpp` fields, the attached child/collection also remembers a
decorator that can mark descendant changes as Dart-only before any listener sees
them.

### Root model special case

`ProjectModel` is the only synced model with no parent. It must be initialized as top-level and explicitly attach children:

1. `isTopLevelModel = true`
2. `setParentPropertiesOnChildren()`

Without this, nested models may not have parent metadata needed for upward propagation.

### First-attach hooks

`onModelFirstAttached(...)` allows a model to queue work that should run only after the model is attached to the tree. This is commonly used when logic requires ancestor access (for example, access to project-level services).

## Change Propagation

### How a change is emitted

For synced fields, generated setters call `notifyFieldChanged(...)` with:

1. a `FieldOperation` (`RawFieldUpdate`, `ListInsert`, `MapPut`, etc.)
2. an initial accessor chain describing the local field access
3. an optional field decorator for direct writes from annotated fields such as
   `@hideFromCpp`

Collection wrappers emit equivalent operations for list/map mutation events.

### How propagation works

`notifyFieldChanged(...)` does the following:

1. notifies listeners registered on the current node
2. appends this node's parent accessor to the chain
3. handles any decorators for the parent field
4. forwards to parent recursively

Listeners receive accessors in root-to-leaf order, making it straightforward to match against higher-level fields first.

### Raw listener API

`AnthemModelBase` exposes low-level listener methods:

- `addRawFieldChangedListener(...)`
- `removeRawFieldChangedListener(...)`

Higher-level generated `onChange(...)` APIs are built on top of this mechanism.

### Detach semantics

`detach()` clears a node's `parent` reference. This prevents stale update forwarding after an object is removed from the model tree but still referenced elsewhere.

Detach is handled automatically in common mutation paths:

- generated synced setters detach old model values when replaced
- `AnthemObservableList`/`AnthemObservableMap` detach removed/replaced model children

## Collection Runtime Behavior

Synced project models must use:

- `AnthemObservableList<T>`
- `AnthemObservableMap<K, V>`

These extend MobX observable collections and also mix in `AnthemModelBase`.

### `AnthemObservableList`

The list wrapper observes element mutations and emits:

- `ListInsert` for adds/inserts
- `ListUpdate` for index replacement
- `ListRemove` for removals

The runtime behavior is as follows:

1. when elements are inserted/removed, parent metadata is re-bound for shifted indices
2. when a model element is replaced/removed, the old model is detached
3. inserted/replaced model elements are attached to this list (when list is attached)

### `AnthemObservableMap`

The map wrapper observes entry mutations and emits:

- `MapPut` for add/update
- `MapRemove` for remove

The runtime behavior is as follows:

1. replaced/removed model values are detached
2. new model values are attached with map-key parent metadata (when map is attached)

### Collection serialization behavior

Both collection wrappers implement `toJson(...)` and serialize recursively using the same runtime rules as model fields:

- primitives are kept as primitives
- enums are serialized by `name`
- nested models call their generated `toJson(...)`
- nested lists/maps are recursively serialized

## MobX "Observe All Changes" Integration

`AnthemModelBase.observeAllChanges()` provides a coarse-grained MobX observation point for "any change in this subtree".

This is intended for performance-sensitive UIs where observing many individual fields would be too expensive.

Use it with the helper APIs in [`lib/model/anthem_model_mobx_helpers.dart`](/lib/model/anthem_model_mobx_helpers.dart):

- `blockObservationBuilder(...)`
- `blockObservation(...)`
- `beginObservationBlockFor(...)` / `endObservationBlockFor(...)`

These helpers temporarily block descendant field-level MobX read tracking while a broader "watch-all" observation is active.

Anthem also guards for mismatched begin/end blocking depth in `App.build()` via `blockObservationBuilderDepth` assertions.

It may be helpful to search the code for usages of `blockObservation` to see use-cases for this. Typically it is used in low-level rendering code, such as the arranger content renderer.

## Source References

- [`codegen/lib/include/model_base_mixin.dart`](/codegen/lib/include/model_base_mixin.dart)
- [`codegen/lib/include/collections.dart`](/codegen/lib/include/collections.dart)
- [`codegen/lib/generators/dart/anthem_model_generator.dart`](/codegen/lib/generators/dart/anthem_model_generator.dart)
- [`lib/model/anthem_model_mobx_helpers.dart`](/lib/model/anthem_model_mobx_helpers.dart)
- [`lib/model/project.dart`](/lib/model/project.dart)
- [`lib/main.dart`](/lib/main.dart)
