# First steps

Anthem is an open-source DAW. It is written in Dart and C++, using Flutter and JUCE.

- Read [the overview docs page](docs/README.md) for an overview of the project architecture.
- Check for a `.dart_tool/` folder in the root of the repository. If it does not exist, you may prompt the user to ensure they have the required prerequisites, then follow the instructions in the relevant setup file in `docs/`. Note that the web setup file is relevant for all platforms.
- Read ./.github/workflows/build.yaml, which contains many useful commands for working with the repo, and examples for running all the tests.

# Repository setup and project-specific commands

- `dart run :cli codegen generate` to generate code. Prefer adding `--root-only` unless running for the first time, if it is not necessary to re-generate model files for the tests in `codegen/` (which is most of the time).
- When building the engine, CI uses the `--release` flag. Prefer `--debug` to `--release` during development.

# Development best practices

- Update the copyright year in headers when making changes.
- In C++, when writing real-time-safe code, use `rt_` to prefix all fields and methods that are only valid when accessed on the audio thread. For example, `rt_myMethod()` and `rt_myField()`, not `rtMyMethod()` or `rtMyField`.

# Directives

- Do not read anything from `docs/design/` unless specifically asked to, as they are not relevant to day-to-day coding tasks.
- Read files from `docs/architecture/` that seem relevant to your task.
- Do not worry about project file migration when making structural changes to the project file. This application is still in development and there are no users.
