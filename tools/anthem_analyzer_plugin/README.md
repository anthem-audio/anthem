# Anthem Analyzer Plugin

Analyzer rules for Anthem.

## Rules

- `invalid_union_assignment`
  - Reports when a value assigned to an `@Union([...])` field is not one of the allowed union types.

## Local Development

```sh
dart test
dart analyze
```

## Docs

For more documentation, please refer to [the analyzer plugin docs](../../docs/codegen/analyzer_plugin.md).
