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
4. Run `.\scripts\build.ps1`. This will build the engine executable and the UI-to-engine IPC layer.
5. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
6. Open a new terminal session and run `flutter pub run build_runner watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
7. Use `flutter run` to run Anthem, or start Anthem via your IDE.
