<img src="https://user-images.githubusercontent.com/6700184/196302775-44ae408b-8271-490b-80d2-c8a69dd3f05d.png" width="150" />

## Anthem

Anthem is a cross-platform open-source DAW, currently in the prototyping stage.

## Contributing

If you're interested in contributing, feel free to open an issue or a discussion thread and I will reply as soon as possible.

## Setup

Anthem is developed with cross-platform technologies, and is designed to run on Windows, macOS and Linux. However, it is currently being developed on Windows and may not run correctly on other platforms yet. If you have any trouble compiling for macOS or Linux, please open an issue.

### Prerequisites

Anthem is developed with the Flutter framework. You can see instructions for installing Flutter for your environment [here](https://docs.flutter.dev/get-started/install).

In addition to Flutter, Anthem needs the following:
- The MSVC C++ compiler (already required by Flutter)
- CMake (https://cmake.org/)
- Boost 1.81.0 or later (https://www.boost.org/). In order for Anthem to find Boost and link to it correctly, make sure to do the following (instructions for Windows):
    1. Download the Boost distribution.
    2. Unzip the distribution somewhere.
    3. Set an evironment variable called `BOOST_ROOT` to the path of the folder you extracted boost into (e.g. "C:/.../Code/boost_1_82_0").
    4. Open a terminal and navigate to the extracted Boost folder.
    5. Run `.\bootstrap.bat`, which generates an executable `.\b2.exe`.
    6. Run `.\b2.exe`.
    7. If you're using Visual Studio Code, you will also need to add the Boost folder to your include path. Open settings (`ctrl + ,` on Windows), type `C_Cpp.default.includePath` in the search bar, click 'Add Item`, paste in your Boost folder path.
- The Flatbuffers v23.3.3 compiler (https://github.com/google/flatbuffers/releases/tag/v23.3.3).
    - Be sure that the flatbuffers compiler (`flatc.exe`) is in your PATH. You should be able to run `flatc -h` from a terminal in any folder.

### Instructions

1. Clone this repository with `--recurse-submodules`: `git clone --recurse-submodules https://github.com/anthem-audio/anthem.git`
2. Navigate to the cloned repository.
3. Run `.\scripts\bindgen.ps1`. We use Flatbuffers to encode messages between the UI and engine processes, and this script generates the Dart and C++ APIs for encoding and decoding the messages.
4. Run `.\scripts\build.ps1`. This will build the engine executable and the UI-to-engine IPC layer.
5. Open a new terminal session and run `flutter pub run build_runner watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
6. Use `flutter run` to run Anthem, or start Anthem via your IDE.
