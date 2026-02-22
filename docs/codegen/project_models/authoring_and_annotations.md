# Project Model Authoring and Annotations

## Scope

This page documents how to author **project model classes** for Anthem's codegen system, with a focus on:

- required model class structure
- annotation behavior and intent
- constraints specific to synced models (`@AnthemModel.syncedModel()`)

This page is not a deep dive into runtime sync internals; that is covered by the runtime-focused pages in this section.

## Required Class Shape

Project model classes are authored in a generated-mixin pattern:

1. A public class (annotated) that mixes in generated code.
2. A base class named with a leading underscore (`_MyModel`) that declares fields.
3. A `part '<file>.g.dart';` directive in the file.

Typical shape:

```dart
part 'my_model.g.dart';

@AnthemModel.syncedModel()
class MyModel extends _MyModel with _$MyModel, _$MyModelAnthemModelMixin {
  MyModel({required super.name});

  MyModel.uninitialized() : super(name: '');

  factory MyModel.fromJson(Map<String, dynamic> json) =>
      _$MyModelAnthemModelMixin.fromJson(json);
}

abstract class _MyModel with Store, AnthemModelBase {
  @anthemObservable
  String name;

  _MyModel({required this.name});
}
```

### Constructor expectations

For generated `fromJson(...)`, codegen expects one of:

1. a `.uninitialized()` named constructor, or
2. a default zero-arg constructor.

Using `.uninitialized()` is the common pattern for non-trivial models. A zero-argument constructor is required for JSON deserialization, where the class is created first and then populated with values.

### Top-level model setup

The root project model (`ProjectModel`) must be marked at runtime as the top-level, and its children must be attached manually after construction/deserialization:

1. `isTopLevelModel = true`
2. `setParentPropertiesOnChildren()`

This is required because parent/child sync metadata is normally attached when a model is assigned into a parent field in another synced model, and `ProjectModel` is the only model with no parent.

### Attachment-time initialization with `onModelFirstAttached(...)`

`AnthemModelBase` provides `onModelFirstAttached(...)` for model logic that must run **after** the model is attached into the model tree (for example, logic that needs access to ancestors like `ProjectModel`).

Typical usage is in the model constructor:

```dart
_MyModel() {
  onModelFirstAttached(() {
    // Safe place to run logic that requires parent/ancestor access
  });
}
```

Authoring rules:

1. Register the callback before the model is attached (usually in the constructor).
2. Do not call it on already-attached models (this throws).
3. Use this for attach-dependent initialization, not ordinary field setup.

The callback executes once, on first attach, and then is cleared.

## Annotation Reference

### `@AnthemModel`

Primary class-level annotation that controls what gets generated.

| Form | Typical use | Effect |
| --- | --- | --- |
| `@AnthemModel.syncedModel(...)` | Project model classes | Enables serialization + C++ generation + model sync + C++ wrapper generation. |
| `@AnthemModel.ipc()` | IPC request/response/message classes | Enables serialization + C++ generation, without model sync. |
| `@AnthemModel(...)` | Advanced/manual configuration | Explicit control over `serializable`, `generateCpp`, `generateModelSync`, `generateCppWrapperClass`, `skipOnWasm`, and behavior-class options. |

Important options on `@AnthemModel(...)`:

| Option | Meaning |
| --- | --- |
| `serializable` | Generate `toJson` / `fromJson`. |
| `generateCpp` | Generate matching C++ type(s). |
| `generateModelSync` | Generate Dart/C++ incremental model sync constructs. |
| `generateCppWrapperClass` | Generate a C++ wrapper class around reflection structs. |
| `skipOnWasm` | Exclude generated C++ model from wasm builds. Used for models that represent desktop-only features (e.g. VST3 plugins). |
| `cppBehaviorClassName` + `cppBehaviorClassIncludePath` | Bind generated model to a hand-authored behavior class; these must be provided together. |

### `@Hide`

Field-level annotation that controls whether a field participates in serialization and/or C++ generation.

Shorthands:

- `@hide` = `@Hide.all()`
- `@hideFromSerialization` = `@Hide(serialization: true)`
- `@hideFromCpp` = `@Hide(cpp: true)`

Behavior matrix:

| Annotation state | Project-file JSON | Engine JSON | C++ field/sync generation |
| --- | --- | --- | --- |
| none | included | included | included |
| `@hideFromSerialization` | **excluded** | included | included |
| `@hideFromCpp` | included | **excluded** | **excluded** |
| `@hide` | **excluded** | **excluded** | **excluded** |

### `@AnthemObservable`

This is a field-level marker for generated MobX integration. It is a drop-in replacement for the `@observable` annotation from MobX. See [the MobX Dart docs](https://mobx.netlify.app/api/observable) for more information.

### `@Union([...])`

Field-level marker for union/polymorphic fields. Rules:

1. Must be placed on an `Object` or `Object?` field.
2. Declares the allowed runtime subtypes for the field.

For project models, this is the supported approach for polymorphism.

Anthem also has an analyzer-plugin diagnostic, `invalid_union_assignment`,
which reports statically when code assigns a type that is not listed in a
field's `@Union([...])` annotation. See [Analyzer Plugin](../analyzer_plugin.md)
for setup, severity, and behavior details.

### `@AnthemEnum()`

Enum-level marker that enables equivalent C++ enum generation. Enums used in Anthem models must have this annotation - if an enum is used by Anthem models and is missing this annotation, codegen will warn, and the C++ will likely not compile.

### `@GenerateCppModuleFile()`

Library-level annotation used on model "module" files (there is currently only one - `lib/model/model.dart`) to generate an aggregate C++ header that includes generated model headers exported by that library.

This defines the include order for C++, so the order of imports here is very important. All C++ files that reference the generated model will import the file that is generated by this annotation.

## Synced-Model Authoring Constraints

These are the practical constraints to follow when authoring project models with `@AnthemModel.syncedModel()`.

### Use Anthem collections for synced fields

For fields that are lists/maps in synced models, use:

- `AnthemObservableList<T>`
- `AnthemObservableMap<K, V>`

These collections are critical to change detection for model syncing, so they must be used. They know how to flow model changes from descendants up the tree, and also know how to generate their own change messages.

### Constants are supported

Generation only includes mutable fields that can be set during deserialization/sync. Fields without setters are skipped, except static-const primitive constants, which are treated as model constants.

For an example of how these constants are used, see the const IDs defined in [`gain.dart`](/lib/model/processing_graph/processors/gain.dart):

- `audioInputPortId`
- `audioOutputPortId`
- `gainPortId`

These IDs are generated as constant values and are available in the C++ as:

- `GainProcessorModelBase::audioInputPortId`
- `GainProcessorModelBase::audioOutputPortId`
- `GainProcessorModelBase::gainPortId`

### Module-file import rule for model sources

Model source files should import concrete model dependencies directly. Do not import Dart module files (libraries annotated with `@GenerateCppModuleFile`) from regular model files, because C++ generation relies on direct dependency visibility.

## Source References

- [`codegen/lib/include/annotations.dart`](/codegen/lib/include/annotations.dart)
- [`codegen/lib/generators/util/model_class_info.dart`](/codegen/lib/generators/util/model_class_info.dart)
- [`codegen/lib/generators/util/model_types.dart`](/codegen/lib/generators/util/model_types.dart)
- [`codegen/lib/generators/dart/anthem_model_generator.dart`](/codegen/lib/generators/dart/anthem_model_generator.dart)
- [`codegen/lib/generators/dart/json_serialize_generator.dart`](/codegen/lib/generators/dart/json_serialize_generator.dart)
- [`codegen/lib/generators/dart/json_deserialize_generator.dart`](/codegen/lib/generators/dart/json_deserialize_generator.dart)
- [`codegen/lib/include/model_base_mixin.dart`](/codegen/lib/include/model_base_mixin.dart)
- [`lib/model/project.dart`](/lib/model/project.dart)
- [`lib/model/model.dart`](/lib/model/model.dart)
- [`lib/model/processing_graph/node.dart`](/lib/model/processing_graph/node.dart)
