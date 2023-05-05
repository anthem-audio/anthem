## Setup on Linux

_Note: These instructions were created on Ubuntu and match our Ubuntu CI builds. You may need to modify these  instructions if you're using a different distro._

### Prerequisites

Anthem is developed with the Flutter framework. [You can see instructions for installing Flutter for Linux here.](https://docs.flutter.dev/get-started/install/linux)

In addition to Flutter, Anthem needs the following:

- **Powershell for Linux**: The build scripts for Anthem are written in Powershell.
- **The Clang compiler**: Used to compile multiple components within Anthem.
- **CMake**: Build tool used for multiple components within Anthem.
- **Make**: Used for assembling Anthem components.
- **Boost 1.72.0 or later**: Required for inter-process communication between the UI and engine.
- **FlatBuffers v23.3.3 compiler**: Required for message serialization between the UI and the engine. Download the compiled Linux binary for 23.3.3 from [the releases page](https://github.com/google/flatbuffers/releases/tag/v23.3.3) and copy the `flatc` binary to `/usr/bin`.
- **Apt packages**: The following packages are required by either JUCE or Flutter, and can be installed with `apt` or a similar package manager:
    ```
    ninja-build llvm clang libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libfreetype-dev mesa-common-dev libasound2-dev freeglut3-dev libxcomposite-dev libgtk-3-dev libasound2-dev libcurl4-openssl-dev libwebkit2gtk-4.0-dev
    ```

### Instructions

1. Clone this repository.
2. Navigate to the cloned repository.
3. Run `git submodule init` and `git submodule update`.
4. Run `powershell ./scripts/build.ps1`. This will generate FlatBuffers files, and build the engine executable and the UI-to-engine IPC layer.
    - Note: You may need to tell CMake which make and compiler tools to use. Anthem is built with `make` and `Clang`. Other tools may work, but are untested. You can tell CMake which tools to use by setting environment variables. Place these in your shell's environment file (e.g. `~/.bashrc` for bash, `/etc/zsh/zshenv` for zsh, etc.):
        ```
        export CC=clang
        export CXX=clang++
        export CMAKE_MAKE_PROGRAM=make
        ```
5. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
6. Open a new terminal session and run `flutter pub run build_runner watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
7. Use `flutter run` to run Anthem, or start Anthem via your IDE.
