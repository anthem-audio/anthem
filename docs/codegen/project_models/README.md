# Project Model Codegen Docs

This section documents the tools and runtime behavior used to build and synchronize Anthem's **project model** between Dart (UI) and C++ (engine).

## Reading Order

If you are new to this area, read in this order:

1. [Project Model Authoring and Annotations](./authoring_and_annotations.md)
2. [Dart Sync Runtime (`AnthemModelBase` and Collections)](./dart_sync_runtime.md)
3. [Change Events and Listeners](./change_events_and_listeners.md)
4. [Engine-Side Change Application (Generated C++)](./engine_side_change_application.md)

## Quick Page Guide

- [Project Model Authoring and Annotations](./authoring_and_annotations.md)
  - How to author model classes, required patterns, annotation behavior, and synced-model constraints.
- [Dart Sync Runtime (`AnthemModelBase` and Collections)](./dart_sync_runtime.md)
  - Attachment lifecycle, parent metadata, change propagation, and collection runtime mechanics.
- [Change Events and Listeners](./change_events_and_listeners.md)
  - Event shapes, generated listener APIs, filter builders, and Dart-to-engine conversion flow.
- [Engine-Side Change Application (Generated C++)](./engine_side_change_application.md)
  - How generated C++ applies updates, initializes child models, and exposes coarse observability hooks.
