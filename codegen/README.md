# Anthem Codegen

`codegen/` is Anthem's model and message code generation module. It serves as the bridge between the Dart UI process and the C++ engine process: it generates serialization code for Dart models, matching C++ model types, and synchronization code so model updates made in the UI can be applied incrementally in the engine.

The module is split into a small runtime surface and a set of builders. `lib/include/` contains annotations and runtime helpers used directly by app code and generated code. `lib/generators/dart/` produces Dart mixins for JSON serialization/deserialization, MobX integration, and model change listeners. `lib/generators/cpp/` emits generated C++ model headers and implementation files in the engine tree, including model sync handlers. `lib/generators/util/` contains shared analyzer/type parsing and writer helpers.

For in-depth documentation of this module, see [../docs/codegen/README.md](../docs/codegen/README.md) and [../docs/codegen/overview.md](../docs/codegen/overview.md).
