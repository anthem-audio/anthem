# Anthem Analyzer Plugin

## Scope

This page documents Anthem's analyzer plugin setup and the custom diagnostics
that are used to catch model/codegen issues earlier than runtime.

The plugin package lives at:

- `tools/anthem_analyzer_plugin`

## Why this exists

Some codegen constraints are difficult to catch with built-in Dart type checks.
For example, union fields are authored with `@Union(...)` and can use a base
type (such as an interface). Without custom diagnostics, invalid declarations
or assignments can fail late during runtime behavior in generated code.

The analyzer plugin allows these mistakes to be reported in-editor and by
`dart analyze` / `flutter analyze`.

## Enabled diagnostics

### `invalid_union_field_type`

Reports when a field declaration uses `@Union([...])`, but one or more listed
types are not assignable to the field's declared type.

Example:

- field type: `Processor`
- union list: `[GainProcessor, String]`
- result: `String` is reported as invalid for that field declaration

### `invalid_union_assignment`

Reports when a value assigned to an `@Union([...])` field is not one of the
allowed types in the annotation.

Currently this checks:

1. Assignment expressions (for example `node.processor = value`)
2. Constructor field initializers (for example `: processor = value`)
3. Named constructor arguments for field/super-field parameters (for example
   `Node(processor: value)`)

This diagnostic is configured at the workspace root in
`analysis_options.yaml`, under `plugins.anthem_analyzer_plugin`, and is
currently promoted to `error`, along with `invalid_union_field_type`.

## Configuration

The root `analysis_options.yaml` enables the plugin:

```yaml
plugins:
  anthem_analyzer_plugin:
    path: tools/anthem_analyzer_plugin
    diagnostics:
      invalid_union_field_type: error
      invalid_union_assignment: error
```

Notes:

1. This must be configured in the **root** analysis options file.
2. After changing plugin configuration, restart the Dart Analysis Server.
3. Diagnostic severities can be adjusted per rule (`info`, `warning`, `error`,
   `false`/disabled), but CI currently expects this rule as `error`.

## Development workflow

Run these commands from the plugin package:

```sh
dart test
dart analyze
```

The main Anthem CI and local lint flow (`dart analyze --fatal-infos`) will also
run plugin diagnostics after plugin configuration is present in root
`analysis_options.yaml`.

## Extending rules

Use one plugin package for multiple Anthem-specific rules. Add new rule classes
under:

- `tools/anthem_analyzer_plugin/lib/src/rules/`

Then register each rule in:

- `tools/anthem_analyzer_plugin/lib/main.dart`

This keeps configuration centralized while allowing per-rule severity and
suppression behavior in analysis options.
