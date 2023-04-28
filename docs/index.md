## Introduction

Anthem is a modern, multi-workflow digital audio workstation (DAW) designed for creating and editing audio content. It is built to be compatible with Windows, macOS, and Linux.

Anthem is developed and maintained by a group of volunteers, with a focus on maintainability, beautiful UI design, and strong usability. This has influenced several key architectural decisions, including:

- **UI with Flutter**: Anthem's UI is built using Flutter, which provides:
  - An effective abstraction for building UIs
  - A time-saving developer experience, with features like hot-reload that improve iteration time
  - A flexible and performant language (Dart) that doesn't get in the way when trying to build complex UIs
  - A mature platform that allows us to focus on solving the problems we care about, instead of building and/or fixing the tools we're using
  - A rendering system that is fast-by-default, and tools for further optimizing performance

- **Tracktion Engine**: The Anthem engine uses Tracktion Engine at its core, enabling the Anthem project to focus on UI design and usability without needing to reinvent an audio engine. Anthem is designed with a strong separation between the UI and the engine, and the engine can be replaced in the future if that serves a design goal. However, it doesn't serve the current project goals to reinvent the wheel here, and Tracktion Engine provides a number of advanced features, such as tempo automation and audio time stretching.

## Getting Started

Anthem is developed with cross-platform technologies, and is designed to run on Windows, macOS and Linux. However, it is currently being developed on Windows and may not run correctly on other platforms yet. If you have any trouble compiling for macOS or Linux, please open an issue.

_Note: The following instructions are for Windows users. macOS and Linux users may need to adapt them accordingly._

### Prerequisites

Anthem is developed with the Flutter framework. You can see instructions for installing Flutter for your environment [here](https://docs.flutter.dev/get-started/install).

In addition to Flutter, Anthem needs the following:

- **The MSVC C++ compiler**: Already required by Flutter for Windows development.
- **CMake**: Required to build the C++ components of Anthem. Download and install CMake from [here](https://cmake.org/).
- **Boost 1.81.0 or later**: Required for inter-process communication between the UI and engine. Download and install Boost from [here](https://www.boost.org/), and follow the instructions below to set it up:
    1. Download the Boost distribution.
    2. Unzip the distribution somewhere.
    3. Set an environment variable called `BOOST_ROOT` to the path of the folder you extracted Boost into (e.g., "C:/.../Code/boost_1_81_0").
    4. If you're using Visual Studio Code, you will also need to add the Boost folder to your include path. Open settings (`ctrl + ,` on Windows), type `C_Cpp.default.includePath` in the search bar, click 'Add Item`, and paste in your Boost folder path.
- **FlatBuffers v23.3.3 compiler**: Required for message serialization between the UI and engine. Download the compiler from [here](https://github.com/google/flatbuffers/releases/tag/v23.3.3), and ensure that the FlatBuffers compiler (`flatc.exe`) is in your PATH. You should be able to run `flatc -h` from a terminal in any folder.

### Instructions

1. Clone this repository with `--recurse-submodules`: `git clone --recurse-submodules https://github.com/anthem-audio/anthem.git`
2. Navigate to the cloned repository.
3. Run `.\scripts\build.ps1`. This will generate FlatBuffers files, and build the engine executable and the UI-to-engine IPC layer.
4. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
5. Open a new terminal session and run `flutter pub run build_runner watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
6. Use `flutter run` to run Anthem, or start Anthem via your IDE.

## Architecture

Anthem has two main components, the UI and the engine, which live in separate processes. The UI process handles most of the logic, while the engine process wraps and controls Tracktion Engine based on commands from the UI. These processes communicate using an IPC channel, with messages encoded using FlatBuffers, a fast and memory-efficient serialization library.

### Message Flow

When the UI wants to do something, it will send a message to the engine. A typical round-trip for a message looks like this:

1. A function in the Dart API for the engine is called, such as `Engine.projectApi.addArrangement()`, which returns a `Future<int>`. The integer it returns represents a pointer to the corresponding Tracktion `Edit` object in the memory space of the engine process.

2. The `addArrangement()` function constructs an `AddArrangement` message with FlatBuffers and sends it to the engine via the engine connector. The engine connector (EngineConnector class in Dart, which has `dart:ffi` bindings to a C++ DLL) has a `message_queue` from `Boost.Interprocess` that it uses to send the bytes from the FlatBuffers message to the engine process.

3. The engine process has an event loop. The main thread of the engine will block while waiting for new messages on the message queue, and will handle messages as they come in. When the engine receives the AddArrangement message, it creates a new `Edit`, gets its pointer, and sends the pointer back to the UI as an integer. This pointer is stored in the UI and is used when manipulating this `Edit`.

4. The UI has a thread (via an `Isolate`) which blocks while waiting for messages from the engine. When this thread receives a message, it copies it into a buffer and notifies the main thread. The main thread decodes the reply and pulls out the pointer, which it uses to complete the future.

## Project structure

The following is an overview of the Anthem project structure:

- **`assets`**: Contains icons and other assets used by the UI. The engine executable and the engine connector dynamic library are both copied here as well, as a way to include them in the Flutter build.
- **`cpp_shared`**: Contains code that is included in multiple C++ projects within the repository.
- **`docs`**: Contains documentation for the project.
- **`engine`**: Contains source code for the Anthem engine. The code in this folder is built into an executable that is run as a separate process from the Flutter UI.
  - **`generated`**: Contains files generated by the FlatBuffers compiler.
  - **`include`**: Contains dependencies of the engine, including JUCE, Tracktion Engine, and FlatBuffers.
  - **`messages`**: Contains `*.fbs` files, which define the messages that can be sent between the engine and the UI. These are compiled with the FlatBuffers compiler into generated C++ and Dart files, which are used by the engine and UI to construct messages.
  - **`src`**: Contains the source code for the Anthem engine.
- **`engine_connector`**: Contains the source code for a dynamic library which is loaded by the UI. This dynamic library contains code for opening and managing an IPC channel (via `message_queue` from `Boost.Interprocess`) between the UI and engine processes.
- **`lib`**: Contains the UI for Anthem.
  - **`commands`**: Anthem uses the command pattern for undo/redo. This folder contains code for actions that can be performed in the UI.
  - **`engine_api`**: Contains an API for interacting with the engine. This API abstracts the low-level communication details and provides a set of `async` functions to the rest of the UI.
  - **`generated`**: Contains generated FlatBuffers files.
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
