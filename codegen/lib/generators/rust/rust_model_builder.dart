// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:analyzer/dart/element/element.dart';
import 'package:anthem_codegen/include.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../util/codegen_dependency_tracker.dart';
import '../util/model_class_info.dart';
import '../util/model_types.dart';

/// This builder generates models in Rust to match the `@AnthemModel` classes in
/// the Dart code.
class RustModelBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    '{{dir}}/{{file}}.dart': ['engine-rust/src/generated/{{dir}}/{{file}}.rs'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) return;
    final library = await buildStep.resolver.libraryFor(buildStep.inputId);

    // Looks for @GenerateRustModels on this library.
    final annotation = const TypeChecker.typeNamed(
      GenerateRustModels,
      inPackage: 'anthem_codegen',
    ).firstAnnotationOf(library);

    // If there is no annotation on this library, don't do anything
    if (annotation == null) return;

    await CodegenDependencyTracker.run(buildStep, (tracker) async {
      cleanModelClassInfoCache();
      tracker.trackLibraryAsset(buildStep.inputId);
      final generator = _RustModels();
      final explicitRoots = annotation.getField('roots')!.toListValue()!;
      final roots = explicitRoots.isNotEmpty
          ? explicitRoots.map((root) => root.toTypeValue()?.element).toList()
          : LibraryReader(library).classes.where((element) {
              final model = const TypeChecker.typeNamed(
                AnthemModel,
                inPackage: 'anthem_codegen',
              ).firstAnnotationOf(element);
              return model?.getField('serializable')?.toBoolValue() == true;
            }).toList();
      if (roots.isEmpty) {
        throw StateError(
          'Rust generation requires at least one serializable root.',
        );
      }
      for (final root in roots) {
        if (root is! ClassElement) {
          throw StateError('Rust model roots must be Anthem model classes.');
        }

        // Create a new ModelClassInfo instance for this class
        generator.collectModel(
          ModelClassInfo(LibraryReader(root.library), root),
        );
      }
      await buildStep.writeAsString(
        AssetId(
          buildStep.inputId.package,
          'engine-rust/src/generated/${buildStep.inputId.changeExtension('.rs').path}',
        ),
        generator.generate(),
      );
    });
  }
}

class _RustModels {
  final _models = <String, ModelClassInfo>{};
  final _sealed = <String, ModelClassInfo>{};
  final _enums = <String, EnumElement>{};
  final _unions = <String, UnionModelType>{};
  final _syncValues = <String>{};

  /// Checks which fields should be included when generating Rust code, based on
  /// the @Hide annotation.
  Iterable<MapEntry<String, ModelFieldInfo>> _fields(ModelClassInfo model) =>
      model.fields.entries.where(
        (field) => field.value.hideAnnotation?.cpp != true,
      );

  Iterable<MapEntry<String, ModelFieldInfo>> _variantFields(
    ModelClassInfo model,
    SealedSubclassInfo subclass,
  ) => {
    ...model.fields,
    ...subclass.fields,
  }.entries.where((field) => field.value.hideAnnotation?.cpp != true);

  String _context(String owner, MapEntry<String, ModelFieldInfo> field) {
    final declaredOn = field.value.fieldElement.enclosingElement.name;
    final name = declaredOn?.replaceFirst(RegExp(r'^_'), '') ?? owner;
    return '$name${_pascal(field.key)}Value';
  }

  void collectModel(ModelClassInfo model) {
    final name = model.annotatedClass.name!;
    final previous = _models[name] ?? _sealed[name];
    if (previous != null) {
      if (previous.annotatedClass != model.annotatedClass) {
        throw StateError(
          'Dart models named $name from different libraries would generate the same Rust type.',
        );
      }
      return;
    }
    if (model.annotation?.serializable != true) {
      throw StateError('$name must be a serializable Anthem model.');
    }
    final synced = model.annotation!.generateModelSync;
    if (synced) _syncValues.add(name);
    if (model.isSealed) {
      _sealed[name] = model;
      _collectFields(name, _fields(model), synced: synced);
      for (final subclass in model.sealedSubclasses) {
        _collectFields(
          subclass.name,
          _variantFields(model, subclass),
          synced: synced,
        );
      }
    } else {
      _models[name] = model;
      _collectFields(name, _fields(model), synced: synced);
    }
  }

  void _collectFields(
    String name,
    Iterable<MapEntry<String, ModelFieldInfo>> fields, {
    bool synced = false,
  }) {
    final identifiers = <String>{};
    for (final field in fields) {
      if (!identifiers.add(_identifier(field.key))) {
        throw StateError('Rust field name collision in $name: ${field.key}.');
      }
      _collectType(field.value.typeInfo, _context(name, field), synced: synced);
    }
  }

  void _collectType(ModelType type, String context, {bool synced = false}) {
    switch (type) {
      case CustomModelType():
        if (synced) _syncValues.add(type.dartName);
        // When deserializing a model (e.g. ProjectModel), Rust will need to have
        // access to the types of all fields in that model, but also of all
        // fields in any child models. This means that we need to recursively
        // process all child models to ensure that they are included in the Rust
        // module.
        collectModel(type.modelClassInfo);
      case EnumModelType():
        if (synced) _syncValues.add(type.enumName);
        final previous = _enums[type.enumName];
        if (previous != null && previous != type.enumElement) {
          throw StateError('Rust enum name collision: ${type.enumName}.');
        }
        _enums[type.enumName] = type.enumElement;
      case ListModelType():
        _collectType(type.itemType, '${context}Item', synced: synced);
      case MapModelType():
        if (type.keyType.isNullable ||
            type.keyType is DoubleModelType ||
            type.keyType is NumModelType) {
          throw StateError(
            '$context: Rust maps require non-null string, integer, boolean, or enum keys.',
          );
        }
        _collectType(type.keyType, '${context}Key', synced: synced);
        _collectType(type.valueType, '${context}Item', synced: synced);
      case UnionModelType():
        if (synced) _syncValues.add(context);
        _unions[context] = type;
        for (final subtype in type.subTypes) {
          _collectType(subtype, '$context${_variant(subtype)}', synced: synced);
        }
      case UnknownModelType():
        throw StateError(
          'Unsupported Rust model type ${type.dartName} in $context.',
        );
      default:
        break;
    }
  }

  String _type(ModelType type, String context, {bool synced = false}) {
    final value = switch (type) {
      StringModelType() => 'String',
      IntModelType() => 'i64',
      DoubleModelType() => 'f64',
      NumModelType() => 'serde_json::Number',
      BoolModelType() => 'bool',
      ColorModelType() => 'crate::model::Color',
      EnumModelType() => type.enumName,
      CustomModelType() =>
        type.modelClassInfo.annotation!.generateModelSync
            ? 'crate::model::ModelRef<${type.dartName}>'
            : type.dartName,
      ListModelType() =>
        '${synced ? 'crate::model::ModelList' : 'Vec'}<${_type(type.itemType, '${context}Item', synced: synced)}>',
      MapModelType() =>
        '${synced ? 'crate::model::ModelMap' : 'std::collections::HashMap'}<${_type(type.keyType, '${context}Key')}, ${_type(type.valueType, '${context}Item', synced: synced)}>',
      UnionModelType() => context,
      UnknownModelType() => throw StateError('Unsupported type in $context.'),
    };
    return type.isNullable ? 'Option<$value>' : value;
  }

  String generate() {
    final names = <String>{};
    for (final name in [
      ..._models.keys,
      ..._sealed.keys,
      ..._enums.keys,
      ..._unions.keys,
    ]) {
      if (!names.add(name)) {
        throw StateError('Rust type name collision: $name.');
      }
    }
    final result = StringBuffer('// Generated by Anthem. Do not edit.\n\n');
    final enums = _enums.keys.toList()..sort();
    for (final name in enums) {
      result.writeln(
        '#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]',
      );
      result.writeln('pub enum $name {');
      final variants = <String>{};
      for (final field in _enums[name]!.fields.where(
        (field) => field.isEnumConstant,
      )) {
        final variant = _pascal(field.name!);
        if (!variants.add(variant)) {
          throw StateError('Rust variant collision in $name.');
        }
        result.writeln('  #[serde(rename = ${_string(field.name!)})]');
        result.writeln('  $variant,');
      }
      result.writeln('}\n');
      if (_syncValues.contains(name)) {
        result.writeln('impl crate::model::sync::ModelValue for $name {}\n');
      }
    }
    final unions = _unions.keys.toList()..sort();
    for (final name in unions) {
      result.writeln('#[derive(Debug, serde::Serialize, serde::Deserialize)]');
      result.writeln('pub enum $name {');
      final variants = <String>{};
      for (final subtype in _unions[name]!.subTypes) {
        final variant = _variant(subtype);
        if (!variants.add(variant)) {
          throw StateError('Rust variant collision in $name.');
        }
        _writePlatformGate(result, subtype);
        result.writeln('  #[serde(rename = ${_string(subtype.dartName)})]');
        result.writeln(
          '  $variant(${_type(subtype, '$name$variant', synced: _syncValues.contains(name))}),',
        );
      }
      result.writeln('}\n');
      if (_syncValues.contains(name)) _writeUnionSync(result, name);
    }
    final sealed = _sealed.keys.toList()..sort();
    for (final name in sealed) {
      final model = _sealed[name]!;

      // If the class is sealed, generate a tagged union that represents the
      // sealed class. This is used for deserialization to define the field
      // ("__type") that will be used to determine the type of the sealed class,
      // and it is used as the runtime type for the deserialized object. At
      // runtime, the actual type can be determined by matching the enum variant.

      if (model.annotation!.skipOnWasm) result.writeln(_desktopGate);
      result.writeln('#[derive(Debug, serde::Serialize, serde::Deserialize)]');
      result.writeln('#[serde(tag = "__type")]');
      result.writeln('pub enum $name {');
      final variants = <String>{};

      // If there are any sealed subclasses, generate variants for them as well.

      for (final subclass in model.sealedSubclasses) {
        final variant = _pascal(subclass.name);
        if (!variants.add(variant)) {
          throw StateError(
            'Rust variant collision in $name: ${subclass.name}.',
          );
        }
        result.writeln('  #[serde(rename = ${_string(subclass.name)})]');
        result.writeln('  $variant {');
        _writeFields(
          result,
          subclass.name,
          _variantFields(model, subclass),
          indent: '    ',
        );
        result.writeln('  },');
      }
      result.writeln('}\n');
      if (model.annotation!.skipOnWasm) result.writeln(_desktopGate);
      result.writeln('impl $name {');
      for (final field in _fields(
        model,
      ).where((field) => !field.value.isModelConstant)) {
        final identifier = _identifier(field.key);
        final copies = _copiesValue(field.value.typeInfo);
        final borrow = copies ? '' : '&';
        result.writeln(
          '  pub fn $identifier(&self) -> $borrow${_type(field.value.typeInfo, _context(name, field))} {',
        );
        result.writeln('    match self {');
        for (final subclass in model.sealedSubclasses) {
          result.writeln(
            '      Self::${_pascal(subclass.name)} { $identifier, .. } => ${copies ? '*' : ''}$identifier,',
          );
        }
        result.writeln('    }');
        result.writeln('  }');
      }
      result.writeln('}\n');
    }
    for (final child in _sealed.values) {
      for (final parent in _sealed.values) {
        if (!child.annotatedClass.allSupertypes.any(
          (type) => type.element == parent.annotatedClass,
        )) {
          continue;
        }
        final childName = child.annotatedClass.name!;
        final parentName = parent.annotatedClass.name!;
        if (child.annotation!.skipOnWasm || parent.annotation!.skipOnWasm) {
          result.writeln(_desktopGate);
        }
        result.writeln('impl From<$childName> for $parentName {');
        result.writeln('  fn from(message: $childName) -> Self {');
        result.writeln('    match message {');
        for (final subclass in child.sealedSubclasses) {
          final fields = _variantFields(child, subclass)
              .where((field) => !field.value.isModelConstant)
              .map((field) => _identifier(field.key))
              .join(', ');
          final variant = _pascal(subclass.name);
          result.writeln(
            '      $childName::$variant { $fields } => Self::$variant { $fields },',
          );
        }
        result.writeln('    }');
        result.writeln('  }');
        result.writeln('}\n');
      }
    }
    final models = _models.keys.toList()..sort();
    for (final name in models) {
      final model = _models[name]!;

      // Generate the main struct.

      if (model.annotation!.skipOnWasm) {
        result.writeln(_desktopGate);
      }
      result.writeln('#[derive(Debug, serde::Serialize, serde::Deserialize)]');
      result.writeln('pub struct $name {');
      _writeFields(
        result,
        name,
        _fields(model),
        public: !model.annotation!.generateModelSync,
        synced: model.annotation!.generateModelSync,
      );
      result.writeln('}\n');
      if (model.annotation!.skipOnWasm) {
        result.writeln(_desktopGate);
      }
      result.writeln('impl $name {');

      /// Writes a set of methods that can be used to get values or references to
      /// the fields in the struct. These can be used to get:
      /// ```rust
      /// let field = model.field();
      /// ```
      for (final field in _fields(model)) {
        // Serialize any constants
        if (field.value.isModelConstant) {
          final value = field.value.fieldElement.computeConstantValue()!;
          final type = field.value.typeInfo;
          final constant = switch (type) {
            StringModelType() => _string(value.toStringValue()!),
            BoolModelType() => value.toBoolValue().toString(),
            IntModelType() => value.toIntValue().toString(),
            DoubleModelType() ||
            NumModelType() => value.toDoubleValue().toString(),
            _ => throw StateError('Unsupported constant $name.${field.key}.'),
          };
          final rustType = type is StringModelType
              ? "&'static str"
              : type is NumModelType
              ? 'f64'
              : _type(type, '');
          result.writeln(
            '  pub const ${_snake(field.key).toUpperCase()}: $rustType = $constant;',
          );
          continue;
        }
        _writePlatformGate(result, field.value.typeInfo);
        final identifier = _identifier(field.key);
        final copiesValue = _copiesValue(field.value.typeInfo);
        final borrow = copiesValue ? '' : '&';
        result.writeln(
          '  pub fn $identifier(&self) -> $borrow${_type(field.value.typeInfo, _context(name, field), synced: model.annotation!.generateModelSync)} {',
        );
        result.writeln('    ${borrow}self.$identifier');
        result.writeln('  }');
      }
      result.writeln('}\n');
      if (_syncValues.contains(name)) _writeModelSync(result, name, model);
    }
    return result.toString();
  }

  void _writeFields(
    StringBuffer result,
    String owner,
    Iterable<MapEntry<String, ModelFieldInfo>> fields, {
    String indent = '  ',
    bool public = false,
    bool synced = false,
  }) {
    for (final field in fields.where((field) => !field.value.isModelConstant)) {
      final type = field.value.typeInfo;
      _writePlatformGate(result, type);
      result.writeln('$indent#[serde(rename = ${_string(field.key)})]');
      if (type.isNullable) {
        result.writeln(
          '$indent#[serde(skip_serializing_if = "Option::is_none")]',
        );
      }
      result.writeln(
        '$indent${public ? 'pub ' : ''}${_identifier(field.key)}: ${_type(type, _context(owner, field), synced: synced)},',
      );
    }
  }

  void _writeModelSync(StringBuffer result, String name, ModelClassInfo model) {
    if (model.annotation!.skipOnWasm) result.writeln(_desktopGate);
    result.writeln('impl crate::model::sync::ModelValue for $name {');
    if (model.annotation!.generateModelSync) {
      result.writeln(
        '  fn apply_update(&mut self, update: crate::model::sync::ModelUpdate<\'_>) -> crate::model::sync::SyncResult {',
      );

      // If this is the last accessor in the chain, then the provided JSON is
      // the new value for the entire model. Deserialization happens before the
      // assignment; the old model stays alive until the outer borrow is released.
      result.writeln(
        '    // 1. Decode and replace the model if the path ends here.',
      );
      result.writeln(
        '    if update.path.is_empty() { return crate::model::sync::replace(self, update); }',
      );

      // If the request is for a field on a child model or collection, forward
      // it to that value. Each collection handles its own elements, so this
      // dispatch does not need to know how deeply the collections are nested.
      result.writeln(
        '    // 2. Apply the update, or forward it to the field that owns it.',
      );
      result.writeln('    let field = update.field()?;');
      result.writeln('    let result = match field {');
      for (final field in _fields(
        model,
      ).where((field) => !field.value.isModelConstant)) {
        _writePlatformGate(result, field.value.typeInfo);
        result.writeln(
          '      ${_string(field.key)} => crate::model::sync::ModelValue::apply_update(&mut self.${_identifier(field.key)}, update.next()),',
        );
      }
      result.writeln(
        '      _ => Err(crate::model::sync::SyncError::new("Unknown or hidden model field")),',
      );
      result.writeln('    };');
      result.writeln(
        '    // 3. Return before cleanup or callbacks. Ancestor borrows are still active here.',
      );
      result.writeln(
        '    result.map_err(|error| error.at(format_args!("$name.{}", field)))',
      );
      result.writeln('  }');
    }
    result.writeln('}\n');
  }

  void _writeUnionSync(StringBuffer result, String name) {
    result.writeln('impl crate::model::sync::ModelValue for $name {');
    result.writeln(
      '  fn apply_update(&mut self, update: crate::model::sync::ModelUpdate<\'_>) -> crate::model::sync::SyncResult {',
    );
    result.writeln(
      '    // Replace the entire union, or forward into its active value.',
    );
    result.writeln(
      '    if update.path.is_empty() { return crate::model::sync::replace(self, update); }',
    );
    result.writeln('    match self {');
    for (final subtype in _unions[name]!.subTypes) {
      _writePlatformGate(result, subtype);
      result.writeln(
        '      Self::${_variant(subtype)}(value) => crate::model::sync::ModelValue::apply_update(value, update),',
      );
    }
    result.writeln('    }');
    result.writeln('  }');
    result.writeln('}\n');
  }
}

bool _copiesValue(ModelType type) => switch (type) {
  IntModelType() ||
  DoubleModelType() ||
  BoolModelType() ||
  EnumModelType() ||
  ColorModelType() => true,
  _ => false,
};

const _desktopGate = '#[cfg(not(target_os = "emscripten"))]';

void _writePlatformGate(StringBuffer result, ModelType type) {
  if (type is CustomModelType && type.modelClassInfo.annotation!.skipOnWasm) {
    result.writeln('  $_desktopGate');
  }
}

String _variant(ModelType type) => _pascal(type.dartName);

String _snake(String name) => name
    .replaceAllMapped(
      RegExp(r'([A-Z]+)([A-Z][a-z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .replaceAll(RegExp('[^a-zA-Z0-9_]'), '_')
    .toLowerCase();

String _pascal(String name) => _snake(name)
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join();

// Raw identifiers let Rust handle keywords without maintaining a keyword list.
String _identifier(String name) => 'r#${_snake(name)}';

String _string(String value) {
  final result = StringBuffer('"');
  for (final rune in value.runes) {
    switch (rune) {
      case 0x22:
        result.write(r'\"');
      case 0x5c:
        result.write(r'\\');
      case 0x0a:
        result.write(r'\n');
      case 0x0d:
        result.write(r'\r');
      case 0x09:
        result.write(r'\t');
      default:
        if (rune < 0x20 || rune == 0x7f) {
          result.write('\\u{${rune.toRadixString(16)}}');
        } else {
          result.writeCharCode(rune);
        }
    }
  }
  result.write('"');
  return result.toString();
}
