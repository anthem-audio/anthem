<img src="https://user-images.githubusercontent.com/6700184/196302775-44ae408b-8271-490b-80d2-c8a69dd3f05d.png" width="150" />

## Anthem

Anthem is a modern, cross-platform digital audio workstation designed for creating and editing music and other audio content. It is desktop-first and works on Windows, macOS and Linux, with a browser-native WASM build coming soon.

Anthem is under active development and currently lacks key functionality and usability features, so it is not yet suitable for use.

## Roadmap

### Existing features

Prior to 2024, development was UI-only, focused on proving out Flutter as a viable UI solution.

Development in 2024 and the first half of 2025 focused on building out Anthem's audio engine. This primarily included building a sequencer and live audio graph, as well as a scalable solution for IPC and state synchronization between the Flutter UI and the C++ engine.

### 2025 & early 2026

Anthem's development is currently focused on building a powerful, usable and productive sequencer. Anthem currently supports MIDI sequencing only, but this is enough to allow us to iterate on the high-level arrangement workflow. Along these lines, we are introducing a novel arranger design that hopes to combine the best of modern pattern-based and linear workflows.

In addition to this, Anthem's architecture already supports compilation to WASM with minimal modification, so we will push for that soon to allow us to build out future features with web support in mind.

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

If you're interested in contributing, feel free to open a discussion thread on this repository, or submit a pull request. Please note that contributions are subject to relicensing; see the note on licensing below.

There is documentation for developers [here](docs/index.md), which includes an architectural overview and setup instructions. There is also inline documentation which we intend to improve over time.

### Source code licensing

Anthem is dual-licensed under a GPL/proprietary license. This is entirely driven by our desire to release software that is compatible with ASIO drivers on Windows. We cannot do this if we license our Windows binaries under GPLv3.

For this reason, Anthem's source code has the following additional constraints:
- Any libraries we use must be compatible with a proprietary licensing model, e.g. they must either themselves have dual-licensing options (e.g. JUCE's free-tier commercial license), or they must be permissively licensed.
- All contributors to Anthem must sign a contributor license agreement that allows relicensing of their contributions under a proprietary license owned by the primary author of Anthem.

We believe that this is the best way to balance the benefit of distributing a truly free ASIO-compatible DAW with the drawbacks of proprietary licensing. In order to ensure that Anthem remains free software, we make the following commitments:
- On platforms besides Windows, binaries will be released under the terms of GPLv3+.
- The proprietary license will be used solely for distribution on Windows.
