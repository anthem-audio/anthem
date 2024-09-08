/*
  Copyright (C) 2024 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:anthem_codegen/generators/util/model_class_info.dart';
import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// This builder generates models in C++ to match the `@AnthemModel` classes in
/// the Dart code.
class CppModelBuilder implements Builder {
  @override
  Future<void> build(BuildStep buildStep) async {
    // This will be written to the output file at the end of the function, if it
    // is not empty.
    var codeToWrite = '';

    // This set contains enums as they are generated. If multiple classes in the
    // same file use the same enum, we only want to generate it once.
    final generatedEnums = <String>{};

    final inputId = buildStep.inputId;
    if (inputId.extension != '.dart') return;

    final LibraryElement library;
    try {
      library = await buildStep.resolver.libraryFor(inputId);
    } catch (ex) {
      return;
    }

    final libraryReader = LibraryReader(library);

    // Looks for @AnthemModel on each class in the file, and generates the
    // appropriate code
    for (final libraryClass in libraryReader.classes) {
      final annotation = libraryClass.metadata
          .where(
            (annotation) =>
                annotation.element?.enclosingElement?.name == 'AnthemModel',
          )
          .firstOrNull;

      // If there is no annotation on this class, don't do anything
      if (annotation == null) continue;

      // Using ConstantReader to read annotation properties
      final reader = ConstantReader(annotation.computeConstantValue());

      // Read properties from @AnthemModel() annotation

      bool generateCpp;

      if (reader.isNull) {
        log.severe(
            '[Anthem codegen] Annotation reader is null for class ${libraryClass.name}. This is either a bug, or we need better error messages here.');
        continue;
      } else {
        // Reading properties of the annotation
        generateCpp = reader.read('generateCpp').literalValue as bool;
      }

      if (!generateCpp) {
        continue;
      }

      // If we have reached this point, we are generating C++ code for this
      // class.

      if (codeToWrite.isEmpty) {
        codeToWrite += '''/*
  This file is generated by the Anthem code generator.
*/

#include <rfl/json.hpp>
#include <rfl.hpp>

''';
      }

      // Create a new ModelClassInfo instance for this class
      final modelClassInfo = ModelClassInfo(libraryReader, libraryClass);

      codeToWrite += '// ${modelClassInfo.annotatedClass.name}\n\n';

      codeToWrite += _generateEnumsForModel(modelClassInfo, generatedEnums);

      // Generate the code for this class
      codeToWrite += _generateStructsForModel(modelClassInfo);

      codeToWrite += '\n\n\n';
    }

    if (codeToWrite.isNotEmpty) {
      final copyAssetId = inputId.changeExtension('.h');
      final inEngine =
          AssetId(copyAssetId.package, 'engine/generated/${copyAssetId.path}');
      await buildStep.writeAsString(inEngine, codeToWrite);
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '{{dir}}/{{file}}.dart': ['engine/generated/{{dir}}/{{file}}.h'],
      };
}

String _generateEnum(EnumModelType enumType) {
  final writer = _Writer();

  writer.writeLine('enum class ${enumType.name} {');
  writer.incrementWhitespace();

  for (final field
      in enumType.enumElement.fields.where((f) => f.name != 'values')) {
    writer.writeLine('${field.name},');
  }

  writer.decrementWhitespace();
  writer.writeLine('};');
  writer.writeLine();

  return writer.result;
}

String _generateEnumsForModel(
    ModelClassInfo modelClassInfo, Set<String> generatedEnums) {
  final writer = _Writer();

  final classEnums = modelClassInfo.fields.values.whereType<EnumModelType>();

  final subclassEnums = modelClassInfo.sealedSubclasses
      .map((subclass) => subclass.fields.values.whereType<EnumModelType>())
      .expand((e) => e); // Flattens the list of lists

  for (final modelType in [classEnums, subclassEnums].expand((e) => e)) {
    if (!generatedEnums.contains(modelType.name)) {
      writer.write(_generateEnum(modelType));
      generatedEnums.add(modelType.name);
    }
  }

  return writer.result;
}

String _generateStructsForModel(ModelClassInfo modelClassInfo) {
  final writer = _Writer();

  var baseText = '';

  if (modelClassInfo.isSealed) {
    baseText = 'Base';
  }

  // Generate the main struct. If the class is sealed, this will be the "base
  // class", and all subclasses will use rfl::Flatten to include this struct.

  writer.writeLine('struct ${modelClassInfo.annotatedClass.name}$baseText {');
  writer.incrementWhitespace();

  for (final MapEntry(key: fieldName, value: modelType)
      in modelClassInfo.fields.entries) {
    final type = _getCppType(modelType);
    writer.writeLine('$type $fieldName;');
  }

  writer.decrementWhitespace();
  writer.writeLine('};');
  writer.writeLine();

  // If there are any sealed subclasses, generate structs for them as well.

  for (final subtype in modelClassInfo.sealedSubclasses) {
    writer.writeLine('struct ${subtype.name} {');
    writer.incrementWhitespace();

    writer.writeLine('using Tag = rfl::Literal<"${subtype.name}">;');
    writer.writeLine();

    for (final MapEntry(key: fieldName, value: modelType)
        in subtype.fields.entries) {
      final type = _getCppType(modelType);
      writer.writeLine('$type $fieldName;');
    }

    final baseClassName = modelClassInfo.annotatedClass.name;
    writer.writeLine(
        'rfl::Flatten<${baseClassName}Base> ${baseClassName[0].toLowerCase() + baseClassName.substring(1)}Base;');

    writer.decrementWhitespace();
    writer.writeLine('};');
    writer.writeLine();
  }

  // If the class is sealed, generate a typedef for a tagged union that
  // represents the sealed class. This is used for deserialization to define the
  // field ("__type") that will be used to determine the type of the sealed
  // class, and it is used as the runtime type for the deserialized object. At
  // runtime, the actual type can be determined using rfl::holds_alternative and
  // passing in the rfl::Variant contained in this type.

  if (modelClassInfo.isSealed) {
    writer.writeLine(
        'using ${modelClassInfo.annotatedClass.name} = rfl::TaggedUnion<');
    writer.incrementWhitespace();
    writer.writeLine('"__type",');

    for (var i = 0; i < modelClassInfo.sealedSubclasses.length; i++) {
      final subtype = modelClassInfo.sealedSubclasses[i];
      final isLast = i == modelClassInfo.sealedSubclasses.length - 1;

      writer.writeLine('${subtype.name}${isLast ? '' : ','}');
    }

    writer.decrementWhitespace();
    writer.writeLine('>;');

    writer.writeLine();
  }

  return writer.result;
}

String _getCppType(ModelType type) {
  return switch (type) {
    StringModelType() => 'std::string',
    IntModelType() => 'int64_t',
    DoubleModelType() || NumModelType() => 'double',
    BoolModelType() => 'bool',
    EnumModelType(enumName: var name) => name,
    ListModelType(itemType: var inner) => 'std::vector<${_getCppType(inner)}>',
    MapModelType(keyType: var key, valueType: var value) =>
      'std::map<${_getCppType(key)}, ${_getCppType(value)}>',
    CustomModelType(name: var name) => name,
    UnknownModelType() => 'TYPE_ERROR_UNKNOWN_TYPE',
  };
}

class _Writer {
  var result = '';
  var whitespace = '';

  void incrementWhitespace() {
    whitespace += '  ';
  }

  void decrementWhitespace() {
    whitespace = whitespace.substring(2);
  }

  void writeLine([String? line]) {
    result += '$whitespace${line ?? ''}\n';
  }

  void write(String line) {
    if (result.isEmpty || result.substring(result.length - 1) == '\n') {
      result += whitespace;
    }
    result += line;
  }
}
