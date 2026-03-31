<img src="https://user-images.githubusercontent.com/6700184/196302775-44ae408b-8271-490b-80d2-c8a69dd3f05d.png" width="150" />

## Anthem

Anthem is a modern, cross-platform digital audio workstation designed for creating and editing music and other audio content. It is desktop-first, and works on Windows, macOS, Linux, and web.

Anthem is under active development and currently lacks key functionality and usability features, so it is not yet suitable for use.

You can [try Anthem in the browser](https://anthem-audio.pages.dev/), or download the latest development build for Windows, macOS or Linux (must be logged in to GitHub):

- Visit https://github.com/anthem-audio/anthem/actions?query=branch%3Amain
- Click on the most recent passing build
- Scroll down to the bottom and click the download button for your platform and architecture

A few notes:
- On Windows, Anthem will be flagged by smart screen. This will cause issues, since Anthem contains two executables. After downloading and **before extracting the zip file**, right click on it and select "Properties", then under "Security:" click the checkbox marked "Unblock".
- macOS builds are not yet signed. There are instructions for running unsigned apps here: https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac
- Linux builds are not yet packaged with dependencies. Linux builds should work on systems that have [all development dependencies installed](./docs/setup_linux.md), but may not work on other systems. Once Anthem reaches a usable state, we plan to provide Snap and/or Flatpak bundles.

## Roadmap

### Existing features

Prior to 2024, development was UI-only, focused on proving out Flutter as a viable UI solution.

Development in 2024 and most of 2025 focused on building out Anthem's audio engine. This primarily included building a sequencer and live audio graph, as well as a scalable solution for IPC and state synchronization between the Flutter UI and the C++ engine.

In last quarter of 2025, the following items were completed:
- Added a web port
- Redesigned automation rendering to improve correctness and performance
- Improved arranger rendering performance by an order of magnitude

### Early 2026

Anthem's development is currently focused on building a powerful, usable and productive sequencer. Anthem currently supports MIDI sequencing only, but this is enough to allow us to iterate on the high-level arrangement workflow. Along these lines, we are introducing an arranger design that hopes to combine the best of modern pattern-based and linear workflows.

### Future

After finishing the above, focus will shift to building out Anthem's other features, including:

- Audio-rate parameter automation
- Audio recording and sequencing
- Support for instrument racks and effects chains
- A mixer
- Limited support for audio feedback loops in the node graph
- Plugin delay compensation
- Basic configuration support, including:
  - Plugin library with automatic plugin discovery
  - Audio environment configuration

This list reflects our current plans but does not represent a commitment of any kind.

## Contributing

Bug reports are always welcome, and are greatly appreciated.

Pull requests are welcome, but will be subject to careful review and may not be accepted for a number of reasons. This includes:
- PRs with mismatched coding style,
- PRs with poor or incompatible code architecture, and
- features that are not compatible with our vision of Anthem.

If you would like to develop a feature for Anthem, you can open a discussion thread on GitHub to discuss the feature and see if it aligns with the current direction of development.

There is documentation for developers [here](docs/README.md), which includes an architectural overview and setup instructions.

## Credits

- Budislav Stepanov - UI/UX design
- Joshua Wade - Code

Special thanks to Stephen Wade for the countless hours spent helping me refine design concepts and software architecture. -Josh
