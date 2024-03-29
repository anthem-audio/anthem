## Setup on Windows

### Prerequisites

Anthem is developed with the Flutter framework. [You can see instructions for installing Flutter for Windows here.](https://docs.flutter.dev/get-started/install/windows)

In addition to Flutter, Anthem needs the following:

- **The MSVC C++ compiler**: Already required by Flutter for Windows development.
- **CMake**: Required to build the C++ components of Anthem. Download and install CMake from [here](https://cmake.org/).
- **Boost 1.81.0 or later**: Required for inter-process communication between the UI and engine. Download and install Boost from [here](https://www.boost.org/), and follow the instructions below to set it up:
    1. Download the Boost distribution.
    2. Unzip the distribution somewhere.
    3. Set an environment variable called `BOOST_ROOT` to the path of the folder you extracted Boost into (e.g., "C:/.../Code/boost_1_81_0").
    4. If you're using Visual Studio Code, you will also need to add the Boost folder to your include path. Open settings (`ctrl + ,`), type `C_Cpp.default.includePath` in the search bar, click 'Add Item`, and paste in your Boost folder path.
- **FlatBuffers v23.3.3 compiler**: Required for message serialization between the UI and the engine. Download the compiler from [here](https://github.com/google/flatbuffers/releases/tag/v23.3.3), and ensure that the FlatBuffers compiler (`flatc.exe`) is in your PATH. You should be able to run `flatc -h` from a terminal in any folder.

### Instructions

1. Clone this repository.
2. Navigate to the cloned repository.
3. Run `git submodule init` and `git submodule update`.
4. Run `.\scripts\build.ps1`. This will generate FlatBuffers files, and build the engine executable and the UI-to-engine IPC layer.
5. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
6. Open a new terminal session and run `flutter pub run build_runner watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
7. Use `flutter run` to run Anthem, or start Anthem via your IDE.
