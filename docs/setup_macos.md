## Setup on macOS

### Prerequisites

Anthem is developed with the Flutter framework. [You can see instructions for installing Flutter for macOS here.](https://docs.flutter.dev/get-started/install/macos/desktop)

Homebrew is recommended for installing CocoaPods and the C++ tooling used by Anthem. You can get Homebrew [here](https://brew.sh/). To install CocoaPods, LLVM, and Ninja with Homebrew, you can use the following command:

```sh
brew install cocoapods llvm ninja
```

In addition to Flutter, Anthem needs the following:

- **CMake**: Required to build the C++ components of Anthem. Download and install CMake from [here](https://cmake.org/).
- **LLVM**: Required for `clang-format` and `clang-tidy`. The Anthem CLI will look in common Homebrew LLVM locations automatically, or you can set `ANTHEM_LLVM_BIN` to the LLVM `bin` directory.
- **Ninja**: Required if you want to mirror the CI clang tooling setup locally.

### Instructions

1. Clone this repository.
2. Navigate to the local clone folder.
3. Run `git submodule init` and `git submodule update`.
4. Run `flutter pub get` in the repository root.
5. `cd` to the `codegen` directory and run `flutter pub get`.
6. `cd` to the `tools/anthem_analyzer_plugin` directory and run `dart pub get`.
7. Return to the repository root and run `dart run anthem:cli codegen generate` to create or update generated code.
8. Run `dart run anthem:cli engine build --debug`. This will build the engine executable.
9. Use the following commands to format and lint engine C++ code:
   - `dart run anthem:cli engine format`
   - `dart run anthem:cli engine lint`
10. (Optional) Open the project in your preferred IDE, such as Visual Studio Code.
11. To keep the generated code updated with the source, you have two options:
   1. Open a new terminal session and run `dart run anthem:cli codegen generate --root-only --watch`. This will run Dart-related code generation, and keep the generated files up-to-date as you develop.
   2. Run `dart run anthem:cli codegen generate --root-only` manually after modifying the model or the IPC messages. This method is a bit more surgical during update, and as a result, C++ build times may be faster when updating generated code with this method.
   - Note: you may need to clean and re-run code generation in order to re-generate the files for the IPC messages if they are changed, since they sometimes don't re-generate automatically. There is a note that prints when running the codegen command above which has more info about this.
12. Use `flutter run` to run Anthem, or start Anthem via your IDE.
