## Introduction

Anthem is a modern, multi-workflow digital audio workstation (DAW) designed for creating and editing audio content. It is built to be compatible with Windows, macOS, and Linux.

Anthem is developed and maintained by volunteers, with a focus on maintainability, beautiful UI design, and strong usability. This has influenced several key architectural decisions, including:

- **UI with Flutter**: Anthem's UI is built using Flutter, which provides:
  - An effective abstraction for building UIs
  - A time-saving developer experience, with features like hot-reload that improve iteration time
  - A flexible and performant language (Dart) that doesn't get in the way when trying to build complex UIs
  - A mature platform that allows us to focus on solving the problems we care about, instead of building or fixing the tools we're using
  - A rendering system that is fast-by-default, and tools for further optimizing performance

- **Audio engine with JUCE**: The audio engine is based on JUCE, which provides a mature API with platform integration for authoring audio software.

## Getting Started

Anthem is developed with cross-platform technologies, and is designed to run on Windows, macOS and Linux. However, it is currently not tested on macOS, and so may not work correctly there. If you have any trouble compiling for or running on macOS, please open an issue.

### Windows

[Setup instructions for Windows](./setup_windows.md)

### Linux

[Setup instructions for Linux](./setup_linux.md)

### Tips for developing

#### Quick reloading of engine executable

In order to see changes when iterating on the engine, you will need to recompile it and load it into the UI. Ordinarily this would require stopping the UI, compiling the engine, then re-compiling the UI.

However, there's a quicker way. By editing [engine_connector.dart](../lib/engine_api/engine_connector.dart), you can override the location where Anthem looks for the Engine executable. By hard-coding the `enginePathOverride` variable to the full path of the executable from your engine build, you can speed up the process. After overriding this variable locally, you can now simply stop the engine from within the UI (by clicking the button at the top-left of the screen with the Anthem icon), build the engine, then start the engine again by clicking the same button.

## Architecture

Anthem has two main components, the UI and the engine, which live in separate processes. The UI process handles most of the logic, while the engine process wraps and controls Tracktion Engine based on commands from the UI. These processes communicate using an IPC channel, with messages encoded using JSON.

### Message Flow

When the UI wants communicate with the engine, it will send a message to the engine over a TCP socket. A typical round-trip for a message looks like this:

1. A function in the Dart API for the engine is called, e.g. `Engine.projectApi.myCommand()`, which returns a `Future<SomeValue>`.

2. The `myCommand()` function constructs an `MyCommandRequest` message with JSON and sends it to the engine via the engine connector. The engine connector uses a socket connection to send the JSON to the engine as a UTF8-encoded string.

3. The engine process has an event loop, provided by JUCE. There is a messaging thread in the engine that will block while waiting for new messages on the message queue, and will register tasks with the JUCE event scheduler to handle each message. When the engine receives the MyCommandRequest message, it handles the message, and sends back a `MyCommandResponse`.

4. The UI listens for replies via the socket connection. When the socket receives a message, it decodes the reply as a `MyCommandResponse` message, and uses the decoded object to complete the future.

Note that the UI sends an ID with each request, and if the engine gives a response, the response will contain the same ID. This allows the UI to align requests and responses.

## Project structure

The following is an overview of the the folder structure in the Anthem repository:

- **`assets`**: Contains icons and other assets used by the UI. The engine executable and the engine connector dynamic library are both copied here as well, as a way to include them in the Flutter build.
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
