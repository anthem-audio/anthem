---
name: get-widget-screenshot
description: Capture PNG screenshots from a minimal testbed app that has full access to Anthem's Dart source code. Allows validation of UI changes; you optionally modify the testbed code to suit your needs, then you use the provided commands to capture the screenshot, then you look at the screenshot to validate changes.
---

# Get Widget Screenshot

Capture screenshots from the testbed app in this repository. This can be used to validate UI changes.

## Run Commands

- Desktop capture with positional args (`<take screenshot> <screen>`):

```bash
flutter run -d (platform) -t lib/main_testbed.dart --dart-entrypoint-args=true --dart-entrypoint-args=button
```

- Desktop capture with explicit output path:

```bash
flutter run -d (platform) -t lib/main_testbed.dart --dart-entrypoint-args=true --dart-entrypoint-args=knob --dart-entrypoint-args=--output=build/widget_testbed_knob.png
```

- Named-flag variant:

```bash
flutter run -d (platform) -t lib/main_testbed.dart --dart-entrypoint-args=--screenshot --dart-entrypoint-args=--screen=button --dart-entrypoint-args=--output=build/widget_testbed_button.png
```

## Screens

See `WidgetTestScreenId` in `lib/widgets/debug/widget_test_area.dart` for a list of screens.

Note that you can make your own screens with widgets if the case requires, prior to running the command.

## Notes

- Use desktop targets (`windows`, `linux`, `macos`) for `--dart-entrypoint-args`.
- The app exits automatically after writing the PNG when screenshot mode is enabled.
