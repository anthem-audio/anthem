## Setup on Linux

_Note: These instructions were created on Ubuntu and match our Ubuntu CI builds. You may need to modify these  instructions if you're using a different distro._

### Prerequisites

Anthem is developed with the Flutter framework. [You can see instructions for installing Flutter for Linux here.](https://docs.flutter.dev/get-started/install/linux/desktop)

In addition to Flutter, Anthem needs the following:

- **The Clang compiler**: Used to compile multiple components within Anthem.
- **CMake**: Build tool used for multiple components within Anthem.
- **Make**: Used for assembling Anthem components.
- **Apt packages**: The following packages are required by either JUCE or Flutter, and can be installed with `apt` or a similar package manager:
    ```
    ninja-build llvm clang libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libfreetype-dev mesa-common-dev libasound2-dev freeglut3-dev libxcomposite-dev libgtk-3-dev libasound2-dev libwebkit2gtk-4.1-dev libcurl4-openssl-dev
    ```

### Instructions

1. Clone this repository.
2. Navigate to the local clone folder.
3. Run `git submodule init` and `git submodule update`.
4. Run `flutter pub get`.
5. `cd` to the `codegen` directory and run `flutter pub get` here as well.
6. Run `dart run anthem:cli codegen generate` to create or update generated code.
7. Run `dart run anthem:cli engine build --debug`. This will build the engine executable.
    - Note: You may need to tell CMake which make and compiler tools to use. Anthem is built with `make` and `Clang`. Other tools may work, but are untested. You can tell CMake which tools to use by setting environment variables. Place these in your shell's environment file (e.g. `~/.bashrc` for bash, `/etc/zsh/zshenv` for zsh, etc.):
        ```
        export CC=clang
        export CXX=clang++
        export CMAKE_MAKE_PROGRAM=make
        ```
8. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
9. Open a new terminal session and run `dart run anthem:cli codegen generate --watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
   - Note: you may need to clean and re-run code generation in order to re-generate the files for the IPC messages if they are changed, since they sometimes don't re-generate automatically. There is a note that prints when running the codegen command above which has more info about this.
10. Use `flutter run` to run Anthem, or start Anthem via your IDE.
