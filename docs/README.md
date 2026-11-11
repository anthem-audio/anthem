# Anthem Docs

## Page Index

- Architecture
  - [Communication Between UI and Engine](./architecture/communication_between_ui_and_engine.md)
  - [Processing Graph](./architecture/processing_graph.md)
  - [Project File Storage](./architecture/project_storage.md)
  - [Sequencer](./architecture/sequencer.md)
  - [State Synchronization](./architecture/state_synchronization.md)
- Codegen
  - [Codegen Docs](./codegen/README.md)
  - [Codegen Overview](./codegen/overview.md)
  - [Codegen Analyzer Plugin](./codegen/analyzer_plugin.md)
- Design
  - [Composable Sequences](./design/composable_sequences.md)
- [Setup on Linux](./setup_linux.md)
- [Setup on macOS](./setup_macos.md)
- [Setup on Windows](./setup_windows.md)
- [Setup for web development](./setup_web.md)
- [Testing](./testing.md)
- [Desktop integration tests](./integration_testing.md)

## Introduction

Anthem is a digital audio workstation (DAW) for creating and editing audio content. It works on Windows, macOS, Linux, and web.

Anthem focuses on maintainability, beautiful UI design, and usability. Its two main components are:

- **The UI**, written in Dart with Flutter, provides the interface and manages projects. Flutter supports a shared UI across platforms and fast iteration during development.
- **The audio engine**, written in C++ with JUCE, handles sequencing, audio processing, and platform audio integration.

## Getting Started

Follow the setup guide for your platform:

- [Windows](./setup_windows.md)
- [Linux](./setup_linux.md)
- [macOS](./setup_macos.md)
- [Web development](./setup_web.md), after the relevant desktop setup

See [Testing](./testing.md) and [Desktop integration tests](./integration_testing.md) for verification instructions.

## Architecture

The UI manages editing and project state; the engine maintains the runtime data and processors needed for playback and rendering. On desktop, they run in separate processes. On web, the engine runs as WebAssembly and communicates with the UI through shared WebAssembly memory.

A simplified path from editing to playback is:

1. The UI changes the project model in response to a user action. Relevant model changes are synchronized to a corresponding model in the engine.
2. The engine prepares sequences and the processing graph for playback. The sequencer supplies timed note and automation events to the graph.
3. The graph routes events, control values, and audio through processors, such as instruments and effects, to the output.
4. The engine sends responses, events, and visualization data back to the UI so it can display results and live feedback.

### Project state and synchronization

The UI owns the Dart project model, which describes the project's arrangement, processing graph, routing, and presentation. It manages editing, saving, and loading. Undoable edits use commands, and MobX observables keep the interface up to date when the model changes.

Generated synchronization code sends relevant model changes one way, from Dart to the engine's corresponding C++ model. The engine owns live processor state. See [State Synchronization](./architecture/state_synchronization.md) and [parameter ownership](./architecture/processing_graph.md#parameter-ownership-and-saved-settings).

Anthem's code generator uses Dart model and message definitions to produce serialization code, corresponding C++ types, and synchronization code for applicable project models. This reduces duplicated definitions across the two languages. See the [Codegen Overview](./codegen/overview.md).

### Sequencing and audio processing

The project contains sequences of musical events and clips that refer to other sequences. The sequencer supplies events at the appropriate time as the transport advances. See [Sequencer](./architecture/sequencer.md).

The processing graph connects processors using audio, note/event, and control data. It routes the sequencer's events through instruments and effects and ultimately to the audio output. The engine compiles sequences and graph instructions outside the audio thread, separating the editable project model from the data used for real-time playback. See [Processing Graph](./architecture/processing_graph.md).

### Message Flow

The Dart engine API handles asynchronous requests, responses, and events between the UI and engine. On desktop, JSON commands and replies use a local TCP connection, while frequent visualization updates use a separate shared-memory channel. On web, both channels use shared WebAssembly memory. See [Communication Between UI and Engine](./architecture/communication_between_ui_and_engine.md) for details.

## Project structure

The main directories are:

- **`lib`**: Dart application code, including the project model (`model`), editing and project logic (`logic`), engine API (`engine_api`), and Flutter UI (`widgets`).
- **`engine`**: C++ engine source, generated code, dependencies, and tests. `engine/src/modules` contains the sequencer, processing graph, processors, and other engine subsystems.
- **`codegen`**: Dart and C++ code generators and their tests.
- **`assets`**: UI assets and resources packaged with the application, including the desktop engine executable.
- **`bin`**: The `anthem:cli` development commands, including code generation and engine builds. Run `dart run anthem:cli -h` for options.
- **`docs`**: Project documentation, including architecture, setup, and testing guides.
- **`test`** and **`integration_test`**: Dart/Flutter tests and desktop integration scenarios. Engine tests live in `engine/test`.
- **`linux`**, **`macos`**, **`windows`**, and **`web`**: Platform-specific application and build files.
