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
4. Run `flutter pub get`.
5. `cd` to the `codegen` directory and run `flutter pub get` here as well.
6. Run `dart run anthem:cli codegen generate` to create or update generated code.
7. Run `dart run anthem:cli engine build --debug`. This will build the engine executable.
8. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
9. Open a new terminal session and run `dart run anthem:cli codegen generate --watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
   - Note: you may need to clean and re-run code generation in order to re-generate the files for the IPC messages if they are changed, since they sometimes don't re-generate automatically. There is a note that prints when running the codegen command above which has more info about this.
10. Use `flutter run` to run Anthem, or start Anthem via your IDE.
