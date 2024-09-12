## Setup on Linux

_Note: These instructions were created on Ubuntu and match our Ubuntu CI builds. You may need to modify these  instructions if you're using a different distro._

### Prerequisites

Anthem is developed with the Flutter framework. [You can see instructions for installing Flutter for Linux here.](https://docs.flutter.dev/get-started/install/linux)

In addition to Flutter, Anthem needs the following:

- **Powershell for Linux**: The build scripts for Anthem are written in Powershell.
- **The Clang compiler**: Used to compile multiple components within Anthem.
- **CMake**: Build tool used for multiple components within Anthem.
- **Make**: Used for assembling Anthem components.
- **Apt packages**: The following packages are required by either JUCE or Flutter, and can be installed with `apt` or a similar package manager:
    ```
    ninja-build llvm clang libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libfreetype-dev mesa-common-dev libasound2-dev freeglut3-dev libxcomposite-dev libgtk-3-dev libasound2-dev libcurl4-openssl-dev libwebkit2gtk-4.0-dev
    ```

### Instructions

1. Clone this repository.
2. Navigate to the local clone folder.
3. Run `git submodule init` and `git submodule update`.
4. Run `powershell ./scripts/build.ps1`. This will build the engine executable and the UI-to-engine IPC layer.
    - Note: You may need to tell CMake which make and compiler tools to use. Anthem is built with `make` and `Clang`. Other tools may work, but are untested. You can tell CMake which tools to use by setting environment variables. Place these in your shell's environment file (e.g. `~/.bashrc` for bash, `/etc/zsh/zshenv` for zsh, etc.):
        ```
        export CC=clang
        export CXX=clang++
        export CMAKE_MAKE_PROGRAM=make
        ```
5. When debugging on Linux, you must override the path that Anthem uses to look for the engine executable. This is because Flutter removes the executable permission when copying the engine executable to the build output directory.

    You can override this by modifying `(repo root)/lib/engine_api/engine_connector.dart`:
    ```dart
    const String? enginePathOverride = "(full path to repo)/assets/engine/AnthemEngine";
    ```
6. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
7. Open a new terminal session and run `flutter pub run build_runner watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
8. Use `flutter run` to run Anthem, or start Anthem via your IDE.
