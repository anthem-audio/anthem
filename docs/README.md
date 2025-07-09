# Anthem Docs

## Page Index

- Architecture
  - [Communication Between UI and Engine](./architecture/communication_between_ui_and_engine.md)
  - [Processing Graph](./architecture/processing_graph.md)
  - [Sequencer](./architecture/sequencer.md)
  - [State Synchronization](./architecture/state_synchronization.md)
- Design
  - [Composable Sequences](./design/composable_sequences.md)
- [Setup on Linux](./setup_linux.md)
- [Setup on macOS](./setup_macos.md)
- [Setup on Windows](./setup_windows.md)

## Introduction

Anthem is a modern, multi-workflow digital audio workstation (DAW) designed for creating and editing audio content. It works on Windows, macOS, and Linux.

Anthem is developed and maintained by volunteers, with a focus on maintainability, beautiful UI design, and strong usability. This has influenced several key architectural decisions, including:

- **UI with Flutter**: Anthem's UI is built using Flutter, which provides:
  - An effective abstraction for building UIs
  - A time-saving developer experience, with features like hot-reload that improve iteration time
  - A flexible and performant language (Dart) that doesn't get in the way when trying to build complex UIs
  - A mature platform that allows us to focus on solving the problems we care about, instead of building or fixing the tools we're using
  - A rendering system that is fast-by-default, and tools for further optimizing performance

- **Audio engine with JUCE**: The audio engine is based on JUCE, which provides a mature API with platform integration for authoring audio software.

## Getting Started

The setup guides below give instructions for setting up Anthem development on your preferred platform.

- [Setup instructions for Windows](./setup_windows.md)
- [Setup instructions for Linux](./setup_linux.md)
- [Setup instructions for macOS](./setup_macos.md)

## Architecture

Anthem has two main components, the UI and the engine, which live in separate processes. These processes communicate using a local TCP socket, with messages encoded using JSON.

The project model is created in Dart, and augmented using code generation. We generate the following code based on the project model:
- Serialization and deserialization methods, for saving project files based on the project model
- C++ models that match the Dart models, so the engine can read from the project model directly from memory
- Methods on the Dart model to automatically generate model update messages, and methods on the generated C++ model to handle these messages, so the C++ model is always up-to-date

We also use code generation to significantly reduce boilerplate and duplicate code for communication between the UI and engine. The message classes in `lib/engine_api/messages/` have matching generated C++ classes, and can be trivially serialized to and from JSON on both ends. See [Message Flow](#Message-Flow) below for more on how this is used. For a deep dive, see [Communication Between UI and Engine](./architecture/communication_between_ui_and_engine.md).

### Authority

The UI is considered authoritative. It owns the project model, and it is the only one allowed to mutate it. Decisions originate from the UI whenever possible, which is the vast majority of the time; the engine simply exists to produce audio based on the project.

### Message Flow

When the UI wants communicate with the engine, it will send a message to the engine over a TCP socket. A typical round-trip for a message looks like this:

1. A function in the Dart API for the engine is called, e.g. `Engine.projectApi.myCommand()`, which returns a `Future<SomeValue>`.

2. The `myCommand()` function constructs an `MyCommandRequest` message with JSON and sends it to the engine via the engine connector. The engine connector uses a socket connection to send the JSON to the engine as a UTF8-encoded string.

3. The engine process has an event loop, provided by JUCE. There is a messaging thread in the engine that will block while waiting for new messages on the message queue, and will register tasks with the JUCE event scheduler to handle each message. When the engine receives the MyCommandRequest message, it handles the message, and sends back a `MyCommandResponse`.

4. The UI listens for replies via the socket connection. When the socket receives a message, it decodes the reply as a `MyCommandResponse` message, and uses the decoded object to complete the future.

Note that the UI sends an ID with each request, and if the engine gives a response, the response will contain the same ID. This allows the UI to align requests and responses.

## Project structure

The following is an overview of the the folder structure in the Anthem repository:

- **`assets`**: Contains icons and other assets used by the UI. The engine executable is copied here as well, as a way to include it in the Flutter build.
- **`bin`**: Contains the `anthem:cli` scripts, used for running code generation and building the engine, among other things. Run `dart run anthem:cli -h` for info.
- **`codegen`**: Contains custom code generation libraries for Anthem, written in Dart. These libraries allow us to define models in Dart, which are then mirrored as C++ models in the engine. JSON serialization and deserialization code is also generated, along with code for automatically synchronizing the two models at runtime.
- **`docs`**: Contains documentation for the project.
- **`engine`**: Contains source code for the Anthem engine. The code in this folder is built into an executable that is run as a separate process from the Flutter UI.
  - **`generated`**: Contains files generated by the Anthem code generator.
  - **`include`**: Contains dependencies of the engine, including JUCE and reflect-cpp.
  - **`src`**: Contains the source code for the Anthem engine.
    - **`command_handlers`**: Contains code for processing commands that come from the UI.
    - **`modules`**: Contains various engine modules.
      - **`core`**: Contains the core application code, which sets up the runtime and includes the other modules.
      - **`processing_graph`**: Contains the code for the graph that drives Anthem's audio processing.
      - **`processors`**: Contains internal plugins for Anthem.
      - **`utils`**: Utilities used by other modules.
- **`lib`**: Contains the UI for Anthem.
  - **`commands`**: Anthem uses the command pattern for undo/redo. This folder contains code for actions that can be performed in the UI.
  - **`controller`**: Meant as "controller" in the MVC sense. Contains classes for logic that are used by commands.
  - **`engine_api`**: Contains an API for interacting with the engine. This API abstracts the low-level communication details and provides a set of `async` functions to the rest of the UI.
  - **`helpers`**: Contains miscellaneous helper functions used by multiple other places in the UI, such as an ID generator.
  - **`model`**: Contains the MobX model used by the rest of the UI. This model also describes the project file structure, and can be serialized to JSON to store and load Anthem project files.
  - **`widgets`**: Contains the Flutter widgets that make up the UI.
    - **`basic`**: Contains widgets that are used across the UI, such as `Button`, `Dropdown`, `Scrollbar`, etc.
    - **`editors`**: Contains editors, such as the piano roll and arranger.
    - **`main_window`**: Contains the code that composes the Anthem UI. This code renders the header bar with tabs for each project, as well as the currently open project.
    - **`project`**: Contains code that composes a view of an Anthem project. This includes rendering the editors and sidebars.
    - **`project_details`**: Contains code for rendering the project details sidebar, with details for various items such as arrangements and patterns.
    - **`project_explorer`**: Contains code for rendering the project explorer sidebar, with a tree view for navigating the project.
- **`linux`**: Contains Flutter platform code for Linux.
- **`macos`**: Contains Flutter platform code for macOS.
- **`scripts`**: Contains scripts for developing, such as build scripts.
- **`windows`**: Contains Flutter platform code for Windows.
