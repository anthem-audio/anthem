# 0.0.0-prealpha.2 (Unreleased)

## New

- Desktop projects are now saved in folders; older project files can be opened and saved in the new format
- Updated arranger design
- Added user-facing errors when a project file fails to load
- Removed support for multiple arrangements per project
- Set default track level to -10db, excluding group, send, and master tracks
- Play button now remains visually pressed while playback is running
- Automation shading now respects parameter baselines, including centered pan
- Added a Settings dialog to choose the default folder for new projects

## Fixed

- Reduced audio latency in web builds
- Steep curves at the start of automation clips now render correctly at all zoom levels
- Fixed VST3 plugin selection on Linux
- Fixed an issue where audio routing data could be deleted if a plugin loaded with a different config than it used when the project was saved
- Added speculative fix for performance issues with visualization data streaming
- Fixed grouping tracks when automation lanes are included in the selection

# 0.0.0-prealpha.1

This is the first release. See below for a feature list; future releases will include change logs.

## Features

- Fully cross-platform, runs on Windows, macOS, and Linux
- Audio processing isolated in a separate process - crashes due to audio instability do not cause lost work
- Multi-threaded audio processing
- Track-based workflow with per-track device chains
- Sequencer with support for MIDI
- Automation tracks and automation clips
- Cross-platform VST3 support
