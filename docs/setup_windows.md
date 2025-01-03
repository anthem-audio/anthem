## Setup on Windows

### Prerequisites

Anthem is developed with the Flutter framework. [You can see instructions for installing Flutter for Windows here.](https://docs.flutter.dev/get-started/install/windows)

In addition to Flutter, Anthem needs the following:

- **The MSVC C++ compiler**: Already required by Flutter for Windows development.
- **CMake**: Required to build the C++ components of Anthem. Download and install CMake from [here](https://cmake.org/).

### Instructions

1. Clone this repository.
2. Navigate to the local clone folder.
3. Run `git submodule init` and `git submodule update`.
4. Run `dart run build_runner build` to create or update generated code.
5. Run `.\scripts\build.ps1`. This will build the engine executable.
6. When debugging on Windows, it is helpful to override the path that Anthem uses to look for the engine executable. This will allow you to load a new engine build into the UI (stop -> rebuild -> start) without re-building the Anthem UI.

    You can override this by modifying `(repo root)/lib/engine_api/engine_connector.dart`:
    ```dart
    const String? enginePathOverride = "(full path to repo)/engine/build/AnthemEngine_artefacts/Debug/AnthemEngine.exe";
    ```
7. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
8. Open a new terminal session and run `flutter pub run build_runner watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
   - Note: you may need to delete `engine/src/generated/lib/engine_api/messages/messages.h` and `lib/engine_api/messages/messages.g.dart`, and run `flutter pub run build_runner build` in order to re-generate the files for the IPC messages if they are changed, since they sometimes don't re-generate automatically.
9. Use `flutter run` to run Anthem, or start Anthem via your IDE.
