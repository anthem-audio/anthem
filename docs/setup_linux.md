## Setup on Linux

_Note: These instructions were created on Ubuntu and match our Ubuntu CI builds. You may need to modify these  instructions if you're using a different distro._

### Prerequisites

Anthem is developed with the Flutter framework. [You can see instructions for installing Flutter for Linux here.](https://docs.flutter.dev/get-started/install/linux/desktop)

In addition to Flutter, Anthem needs the following:

- **The Clang compiler**: Used to compile multiple components within Anthem. Use LLVM/Clang 22 to match CI.
- **CMake**: Build tool used for multiple components within Anthem.
- **Make**: Used for assembling Anthem components.
- **Apt packages**: The following packages are required by either JUCE or Flutter, and can be installed with `apt` or a similar package manager:
   ```
   ninja-build llvm-22 clang-22 clang-format-22 clang-tidy-22 libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libfreetype-dev mesa-common-dev libasound2-dev freeglut3-dev libxcomposite-dev libgtk-3-dev libasound2-dev libwebkit2gtk-4.1-dev libcurl4-openssl-dev
   ```
  On Ubuntu, the `clang-format` package provided by the default distribution repositories may be an older LLVM version. If `llvm-22`, `clang-22`, `clang-format-22`, or `clang-tidy-22` are not available, install LLVM 22 from [apt.llvm.org](https://apt.llvm.org/).

Set `ANTHEM_LLVM_BIN` to the LLVM 22 `bin` directory if those tools are not exposed as the default `clang`, `clang-format`, and `clang-tidy` on `PATH`:

```sh
export ANTHEM_LLVM_BIN=/usr/lib/llvm-22/bin
```

### Instructions

1. Clone this repository.
2. Navigate to the local clone folder.
3. Run `git submodule init` and `git submodule update`.
4. Run `flutter pub get` in the repository root.
5. `cd` to the `codegen` directory and run `flutter pub get`.
6. `cd` to the `tools/anthem_analyzer_plugin` directory and run `dart pub get`.
7. Return to the repository root and run `dart run anthem:cli codegen generate` to create or update generated code.
8. Run `dart run anthem:cli engine build --debug`. This will build the engine executable.
   - Note: You may need to tell CMake which make and compiler tools to use. Anthem is built with `make` and `Clang`. Other tools may work, but are untested. You can tell CMake which tools to use by setting environment variables. Place these in your shell's environment file (e.g. `~/.bashrc` for bash, `/etc/zsh/zshenv` for zsh, etc.):
      ```
      export CC=/usr/lib/llvm-22/bin/clang
      export CXX=/usr/lib/llvm-22/bin/clang++
      export CMAKE_MAKE_PROGRAM=make
      ```
9. Use the following commands to format and lint engine C++ code:
   - `dart run anthem:cli engine format`
   - `dart run anthem:cli engine lint`
10. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
11. To keep the generated code updated with the source, you have two options:
   1. Open a new terminal session and run `dart run anthem:cli codegen generate --root-only --watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
   2. Run `dart run anthem:cli codegen generate --root-only` manually after modifying the model or the IPC messages. This method is a bit more surgical during update, and as a result, C++ build times may be faster when updating generated code with this method.
   - Note: you may need to clean and re-run code generation in order to re-generate the files for the IPC messages if they are changed, since they sometimes don't re-generate automatically. There is a note that prints when running the codegen command above which has more info about this.
12. Use `flutter run` to run Anthem, or start Anthem via your IDE.
