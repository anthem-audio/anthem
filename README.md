# anthem

Rust Integrated Dart Flutter Project

## Installing LLVM
Rust Integrated Dart uses LLVM. Install LLVM (9+) in the following way.

#### Ubuntu
1. Install libclangdev - `sudo apt-get install libclang-dev`.

#### Windows
1. Install Visual Studio with C++ development support.
2. Install [LLVM](https://releases.llvm.org/download.html) or `winget install -e --id LLVM.LLVM`.

#### macOS
1. Install Xcode.
2. Install LLVM - `brew install llvm`.

## Getting Started

Use the below scripts to get the app ready to run with Flutter.

### 1. Generate Glue Code

```sh
./sh/bindgen
```

### 2. Build For Desired Target/Device

Run any of the below three to build the binary for the specific device and have it placed into
the devices specific plugin folder.

```sh
./sh/macos
```

### 3. Run with Flutter

Run on the device.

```sh
flutter run -d macos
```

### 4. Develop

Run step `1` whenever a function exposed to Flutter changes.

Run step `2` whenever any of your Rust code changes.

**Note** that to apply changes from Rust you need to restart the app to reload the compiled binary.
A hot restart/reload does not achieve this.

## Folder Structure

```
├── android
├── ios
├── macos
├── lib
├── plugin
│   ├── android
│   ├── ios
│   ├── macos
│   └── lib
└── src
```

### `./plugin`

Provides connection from Flutter to Rust.

Rust binaries are placed into the respective plugin folders `./ios, ./macos, ./android` when
they are built.

Generated Dart glue code is placed inside `./plugin/lib/generated` while
`./plugin/lib/plugin.dart` just exposes the API to the app.

### `./src`

Contains the starter Rust code inside `./src/lib.rs`. Keep developing the Rust part of your app
here.

### `./lib`

Contains the starter Flutter app inside `./lib/main.dart`.

### `./sh`

Provides scripts to run build and code generation tasks. In the future a tool will provide the
functionality currently provided by these scripts.

- `bindgen` generates the `binding.h` header file for the extern Rust functions found inside
  `./src`. These are then placed inside the `./plugin` device folders were needed as well as
  `./plugin/lib/generated/binding.h` where they are used to generate Dart glue code
  - as part of this script `ffigen` generates Dart glue code inside
    `./plugin/lib/generated/ffigen_binding.dart` using `./plugin/lib/generated/binding.h` as input
- `./android` builds the Rust binary to run on Android devices/emulators and places it inside
  `./plugin/lib/android`
- `./ios` builds the Rust binary to run on IOS devices/emulators and places it inside
  `./plugin/lib/ios`
- `./macos` builds the Rust binary to run on MacOs directly and places it inside
  `./plugin/lib/macos`, this is the same format as running `cargo build` on your Mac
- `clean` cleans both the Flutter plugin and application, run this to reset Flutter when things
  aren't working
