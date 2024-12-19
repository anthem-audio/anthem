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
import 'package:anthem_codegen/generators/cpp/cpp_model_sync.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../util/enum_info.dart';
import '../util/model_class_info.dart';
import '../util/model_types.dart';
import '../util/writer.dart';
import 'shared.dart';

/// This builder generates models in C++ to match the `@AnthemModel` classes in
/// the Dart code.
class CppModelBuilder implements Builder {
  @override
  Future<void> build(BuildStep buildStep) async {
    cleanModelClassInfoCache();

    // A list of models that are in this file. We use this while generating
    // imports to ensure that the generated imports are only for fields that are
    // not hidden.
    List<ModelClassInfo> classesProcessed = [];

    final inputId = buildStep.inputId;
    if (inputId.extension != '.dart') return;

    final LibraryElement library;
    try {
      library = await buildStep.resolver.libraryFor(inputId);
    } catch (ex) {
      return;
    }

    final libraryReader = LibraryReader(library);

    // Header file definitions
    final headerImports = <String>[];
    final forwardDeclarations = <String>[];
    final usingDirectives = <String>[];
    final moduleFileImports = <String>[]; // See note below
    final codeBlocks = <String>[];

    // C++ file definitions
    final cppFileImports = <String>[];
    final functionDefinitions = <String>[];

    // Note that module file imports are only used for module files. There is a
    // detailed description in the doc comment on the @GenerateCppModuleFile
    // annotation.

    // Looks for @GenerateCppModuleFile on this library.
    final libraryAnnotation = library.metadata
        .where(
          (annotation) =>
              annotation.element?.enclosingElement?.name ==
              'GenerateCppModuleFile',
        )
        .firstOrNull;

    // If we should generate a C++ module file from this file, we kick off the
    // function to do it here.
    if (libraryAnnotation != null) {
      final result = _generateCppModuleFile(libraryReader);
      moduleFileImports.addAll(result.imports);
      forwardDeclarations.addAll(result.forwardDeclarations);
    }

    // Warn for enums that are not annotated with @AnthemEnum
    for (final classElement in libraryReader.classes) {
      final annotation = const TypeChecker.fromRuntime(AnthemModel)
          .firstAnnotationOf(classElement);

      if (annotation == null) continue;

      final classInfo = ModelClassInfo(libraryReader, classElement);

      for (final fieldInfo in classInfo.fields.values) {
        if (fieldInfo.typeInfo is! EnumModelType) continue;

        // Check for enum annotation
        final enumAnnotation = const TypeChecker.fromRuntime(AnthemEnum)
            .firstAnnotationOf(fieldInfo.fieldElement.type.element!);

        final hideAnnotation = const TypeChecker.fromRuntime(Hide)
            .firstAnnotationOf(fieldInfo.fieldElement);

        // If the enum is not annotated with @anthemEnum, then some necessary
        // codegen may not happen.
        if (enumAnnotation == null) {
          // Double-check that this field is not hidden from codegen before
          // logging a warning.
          if (hideAnnotation == null ||
              hideAnnotation.getField('cpp')?.toBoolValue() == false) {
            log.warning(
                'Enum ${fieldInfo.fieldElement.type.element?.name} is not annotated with @anthemEnum. This is required for enums that are used by Anthem models.');
            log.warning(
                'The enum ${fieldInfo.fieldElement.type.element?.name} is used in a field called ${fieldInfo.fieldElement.name} on ${classElement.name}.');
          }
        }
      }
    }

    final (code: enumsCode, forwardDeclarations: enumsForwardDeclarations) =
        _generateEnumsForLibrary(
      libraryReader.enums
          .where((e) {
            final annotation =
                const TypeChecker.fromRuntime(AnthemEnum).firstAnnotationOf(e);
            return annotation != null;
          })
          .map((e) => EnumInfo(e))
          .toList(),
    );

    if (enumsCode.isNotEmpty) {
      codeBlocks.add(enumsCode);
    }
    forwardDeclarations.addAll(enumsForwardDeclarations);

    // Looks for @AnthemModel on each class in the file, and generates the
    // appropriate code
    for (final libraryClass in libraryReader.classes) {
      final annotation = const TypeChecker.fromRuntime(AnthemModel)
          .firstAnnotationOf(libraryClass);

      // If there is no annotation on this class, don't do anything
      if (annotation == null) {
        continue;
      }

      // Read properties from @AnthemModel() annotation

      final generateCpp =
          annotation.getField('generateCpp')?.toBoolValue() ?? false;

      if (!generateCpp) {
        continue;
      }

      // If we have reached this point, we are generating C++ code for this
      // class.

      // Create a new ModelClassInfo instance for this class
      final modelClassInfo = ModelClassInfo(libraryReader, libraryClass);
      classesProcessed.add(modelClassInfo);

      if (modelClassInfo.annotation!.generateModelSync) {
        // The model sync code needs ModelUpdateRequest, which comes from the
        // messaging model
        headerImports.add('#include "messages/messages.h"');

        // If the model is being synced, then we will generate observability
        // code for it. This requires including the observability header.
        headerImports
            .add('#include "modules/codegen_helpers/observability_helpers.h"');
      }

      codeBlocks.add('// ${modelClassInfo.annotatedClass.name}\n\n');

      // Generate the code for this class
      final (
        code: structsCode,
        forwardDeclarations: structsForwardDeclarations,
        usingDirectives: structUsingDirectives,
        cppFileImports: structCppFileImports,
        functionDefinitions: structFunctionDefinitions,
      ) = _generateStructsForModel(modelClassInfo);

      codeBlocks.add(structsCode);
      forwardDeclarations.addAll(structsForwardDeclarations);
      usingDirectives.addAll(structUsingDirectives);
      cppFileImports.addAll(structCppFileImports);
      functionDefinitions.addAll(structFunctionDefinitions);

      codeBlocks.add('\n\n\n');
    }

    // Checks the imports of this library for any that themselves contain Anthem
    // models, and generates the appropriate imports for the C++ module file.
    for (final importElement in library.libraryImports) {
      final importLibrary = importElement.importedLibrary;

      if (importLibrary == null) {
        continue;
      }

      final importLibraryReader = LibraryReader(importLibrary);

      List<ClassElement> annotatedClasses = [];
      List<EnumElement> annotatedEnums = [];

      for (final classElement in importLibraryReader.classes) {
        final annotation = const TypeChecker.fromRuntime(AnthemModel)
            .firstAnnotationOf(classElement);

        if (annotation == null) {
          continue;
        }

        final generateCpp =
            annotation.getField('generateCpp')?.toBoolValue() ?? false;

        if (generateCpp) {
          annotatedClasses.add(classElement);
        }
      }

      for (final enumElement in importLibraryReader.enums) {
        final annotation = const TypeChecker.fromRuntime(AnthemEnum)
            .firstAnnotationOf(enumElement);

        if (annotation == null) {
          continue;
        }

        annotatedEnums.add(enumElement);
      }

      if (annotatedClasses.isEmpty && annotatedEnums.isEmpty) {
        continue;
      }

      // Ensure that at least one of the annotated classes is actually used in
      // this file. If none are, we shouldn't generate an import for this file.
      //
      // This is because we may, for example, have a field in the Dart class that
      // references another model, such as the parent model, but we hide this from
      // all codegen. If this is the case, we may import the parent model in the
      // Dart code, but we do not want to import it in the C++ code because it's
      // not actually used (and may cause circular import issues).
      var foundMatch = false;
      outer:
      for (final modelClassInfo in classesProcessed) {
        for (final field in modelClassInfo.fields.values) {
          // Recursively checks if the given type uses any type that comes from
          // imported library that we're currently checking.
          bool typeMatches(ModelType type) {
            if (type is ListModelType) {
              return typeMatches(type.itemType);
            } else if (type is MapModelType) {
              return typeMatches(type.keyType) || typeMatches(type.valueType);
            } else if (type is CustomModelType) {
              if (annotatedClasses
                  .contains(type.modelClassInfo.annotatedClass)) {
                return true;
              }
            } else if (type is EnumModelType) {
              final enumModelType = type;
              if (annotatedEnums.contains(enumModelType.enumElement)) {
                return true;
              }
            }

            return false;
          }

          if (typeMatches(field.typeInfo)) {
            foundMatch = true;
            break outer;
          }
        }
      }

      if (!foundMatch) {
        continue;
      }

      final uri = importElement.uri;
      if (uri is DirectiveUriWithLibrary) {
        final pathStr = uri.relativeUri
            .toString()
            .replaceFirst('.dart', '.h')
            .replaceFirst('package:anthem/', 'generated/lib/');
        headerImports.add('#include "$pathStr"');
      }
    }

    // If we didn't generate any items for this file, don't try to write
    // anything.
    //
    // Note that imports is not included here. If we generate a file with only
    // imports, but everything else is skipped, we still want to skip writing
    // the file.
    if (forwardDeclarations.isEmpty &&
        usingDirectives.isEmpty &&
        moduleFileImports.isEmpty &&
        codeBlocks.isEmpty &&
        cppFileImports.isEmpty &&
        functionDefinitions.isEmpty) {
      return;
    }

    var headerCodeToWrite = '''/*
  This file is generated by the Anthem code generator.
*/

#pragma once

#include <rfl/json.hpp>
#include <rfl.hpp>

#include "modules/codegen_helpers/anthem_model_base.h"
#include "modules/codegen_helpers/anthem_model_vector.h"
#include "modules/codegen_helpers/anthem_model_unordered_map.h"

''';

    var cppCodeToWrite = '''/*
  This file is generated by the Anthem code generator.
*/

#include "${inputId.pathSegments.last.replaceAll('.dart', '.h')}"

''';

    for (final import in headerImports) {
      headerCodeToWrite += import;
      headerCodeToWrite += '\n';
    }

    headerCodeToWrite += '\n';

    for (final import in cppFileImports) {
      cppCodeToWrite += import;
      cppCodeToWrite += '\n';
    }

    cppCodeToWrite += '\n';

    // We forward declare all enums and structs at the top of the file, to
    // ensure that order doesn't matter when actually defining the structs and
    // enums.
    for (final forwardDeclaration in forwardDeclarations) {
      headerCodeToWrite += forwardDeclaration;
      headerCodeToWrite += '\n';
    }

    headerCodeToWrite += '\n';

    // Sealed classes use a "using" directive to define a tagged union type that
    // represents the sealed class. We declare this after the forward
    // declarations so all the types are accessible, but before the structs are
    // defined so the structs can use these types.
    for (final usingDirective in usingDirectives) {
      headerCodeToWrite += usingDirective;
      headerCodeToWrite += '\n';
    }

    for (final import in moduleFileImports) {
      headerCodeToWrite += import;
      headerCodeToWrite += '\n';
    }

    headerCodeToWrite += '\n';

    // The rest of the code blocks are the structs and enums themselves.
    for (final codeBlock in codeBlocks) {
      headerCodeToWrite += codeBlock;
      headerCodeToWrite += '\n';
    }

    for (final functionDefinition in functionDefinitions) {
      cppCodeToWrite += functionDefinition;
      cppCodeToWrite += '\n';
    }

    final headerAssetId = inputId.changeExtension('.h');
    final headerAssetIdInEngine = AssetId(
        headerAssetId.package, 'engine/src/generated/${headerAssetId.path}');
    await buildStep.writeAsString(headerAssetIdInEngine, headerCodeToWrite);

    if (functionDefinitions.isNotEmpty) {
      final cppAssetId = inputId.changeExtension('.cpp');
      final cppAssetIdInEngine = AssetId(
          cppAssetId.package, 'engine/src/generated/${cppAssetId.path}');
      await buildStep.writeAsString(cppAssetIdInEngine, cppCodeToWrite);
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '{{dir}}/{{file}}.dart': [
          'engine/src/generated/{{dir}}/{{file}}.h',
          'engine/src/generated/{{dir}}/{{file}}.cpp'
        ],
      };
}

String _generateEnum(EnumInfo enumInfo) {
  final writer = Writer();

  writer.writeLine('enum class ${enumInfo.name} {');
  writer.incrementWhitespace();

  for (final value in enumInfo.values.where((value) => value != 'values')) {
    writer.writeLine('$value,');
  }

  writer.decrementWhitespace();
  writer.writeLine('};');
  writer.writeLine();

  return writer.result;
}

({String code, List<String> forwardDeclarations}) _generateEnumsForLibrary(
    List<EnumInfo> enums) {
  final forwardDeclarations = <String>[];
  final writer = Writer();

  for (final enumInfo in enums) {
    writer.write(_generateEnum(enumInfo));
    forwardDeclarations.add('enum class ${enumInfo.name};');
  }

  return (code: writer.result, forwardDeclarations: forwardDeclarations);
}

({
  String code,
  List<String> forwardDeclarations,
  List<String> usingDirectives,
  List<String> cppFileImports,
  List<String> functionDefinitions,
}) _generateStructsForModel(ModelClassInfo modelClassInfo) {
  final forwardDeclarations = <String>[];
  final usingDirectives = <String>[];
  final cppFileImports = <String>[];
  final functionDefinitions = <String>[];
  final writer = Writer();

  final generateModelSync =
      modelClassInfo.annotation?.generateModelSync == true;
  final generateWrapper =
      modelClassInfo.annotation?.generateCppWrapperClass == true;

  var baseText = '';

  if (modelClassInfo.isSealed) {
    if (generateWrapper) {
      // Sealed classes are generated with tagged unions, and that complicates
      // the story for a wrapper class, so we won't handle it for now.
      throw ArgumentError(
          'Cannot generate a wrapper class for a sealed class.');
    }

    baseText = 'Base';
  }

  if (generateWrapper) {
    baseText = 'Impl'; // Convention borrowed from reflect-cpp docs
  }

  // Generate the main struct. If the class is sealed, this will be the "base
  // class", and all subclasses will use rfl::Flatten to include this struct.

  forwardDeclarations
      .add('struct ${modelClassInfo.annotatedClass.name}$baseText;');

  writer.writeLine('struct ${modelClassInfo.annotatedClass.name}$baseText {');
  writer.incrementWhitespace();

  for (final MapEntry(key: fieldName, value: fieldInfo)
      in modelClassInfo.fields.entries) {
    if (_shouldSkip(fieldInfo.fieldElement)) {
      continue;
    }

    if (fieldInfo.isModelConstant) {
      if (!generateWrapper) {
        final type = getCppType(fieldInfo.typeInfo, modelClassInfo);
        writer.writeLine(
            'static const $type $fieldName = ${fieldInfo.constantValue};');
      }
    } else {
      final type = getCppType(fieldInfo.typeInfo, modelClassInfo);
      writer.writeLine('$type $fieldName;');
    }
  }

  writer.writeLine();

  if (generateModelSync && !generateWrapper) {
    cppFileImports.addAll(getCppFileImports(modelClassInfo));

    writeModelSyncFnDeclaration(writer);
    functionDefinitions.add(getInitializeFn(modelClassInfo));
    functionDefinitions.add(getModelSyncFn(modelClassInfo));
  }

  writer.decrementWhitespace();
  writer.writeLine('};');
  writer.writeLine();

  // If we need to generate a wrapper class for this model, do so now.

  if (generateWrapper) {
    final className = modelClassInfo.annotatedClass.name;
    final baseSuffix =
        modelClassInfo.annotation?.cppBehaviorClassName != null ? 'Base' : '';

    forwardDeclarations.add('class $className$baseSuffix;');

    var outwardFacingClassName = '$className$baseSuffix';
    if (baseSuffix.isNotEmpty) {
      outwardFacingClassName = modelClassInfo.annotation!.cppBehaviorClassName!;
      forwardDeclarations.add('class $outwardFacingClassName;');
    }

    writer.writeLine('class $className$baseSuffix : public AnthemModelBase {');
    writer.writeLine('public:');
    writer.incrementWhitespace();

    // Serialize any constants
    for (final field in modelClassInfo.fields.values) {
      if (!field.isModelConstant) {
        continue;
      }

      final type = getCppType(field.typeInfo, modelClassInfo);
      writer.writeLine(
          'static const $type ${field.fieldElement.name} = ${field.constantValue};');
    }

    writer.writeLine('using ReflectionType = ${className}Impl;');
    writer.writeLine();

    writer.writeLine(
        '$className$baseSuffix(const ${className}Impl& _impl) : impl(_impl) {}');
    writer.writeLine();

    writer.writeLine('~$className$baseSuffix() = default;');
    writer.writeLine();

    // Delete copy constructor and assignment operator
    writer.writeLine(
        '$className$baseSuffix(const $className$baseSuffix&) = delete;');
    writer.writeLine(
        '$className$baseSuffix& operator=(const $className$baseSuffix&) = delete;');
    writer.writeLine();

    // Create a move constructor and assignment operator
    writer.writeLine(
        '$className$baseSuffix($className$baseSuffix&&) noexcept = default;');
    writer.writeLine(
        '$className$baseSuffix& operator=($className$baseSuffix&&) noexcept = default;');
    writer.writeLine();

    writer
        .writeLine('const ReflectionType& reflection() const { return impl; }');
    writer.writeLine();

    writer.writeLine(
        'void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override;');
    writer.writeLine();

    if (generateModelSync) {
      cppFileImports.addAll(getCppFileImports(modelClassInfo));

      writeModelSyncFnDeclaration(writer);
      writer.writeLine();

      functionDefinitions.add(getInitializeFn(modelClassInfo));
      functionDefinitions.add(getModelSyncFn(modelClassInfo));
    }

    writer.writeLine('// Reference getters');

    List<String> privateObserverCollections = [];

    /// Writes a set of methods that can be used to get references to the fields
    /// in the impl struct. These can be used to get:
    /// ```
    /// auto& field = model.field();
    /// ```
    ///
    /// Or to set:
    /// ```
    /// model.field() = value;
    /// ```
    for (final MapEntry(key: fieldName, value: fieldInfo)
        in modelClassInfo.fields.entries) {
      if (_shouldSkip(fieldInfo.fieldElement) || fieldInfo.isModelConstant) {
        continue;
      }

      final type = getCppType(fieldInfo.typeInfo, modelClassInfo);
      writer.writeLine('$type& $fieldName() { return impl.$fieldName; }');

      if (generateModelSync) {
        final upperCamelCaseFieldName =
            fieldName[0].toUpperCase() + fieldName.substring(1);
        writer.writeLine(
            'ObserverHandle add${upperCamelCaseFieldName}Observer(std::function<void($type)> callback) {');
        writer.incrementWhitespace();
        writer.writeLine('return ${fieldName}Observers.addObserver(callback);');
        writer.decrementWhitespace();
        writer.writeLine('}');

        writer.writeLine(
            'void remove${upperCamelCaseFieldName}Observer(ObserverHandle handle) {');
        writer.incrementWhitespace();
        writer.writeLine('${fieldName}Observers.removeObserver(handle);');
        writer.decrementWhitespace();
        writer.writeLine('}');

        privateObserverCollections
            .add('FieldObservers<$type> ${fieldName}Observers;');
      }
    }

    writer.writeLine();

    writer.decrementWhitespace();
    writer.writeLine('private:');
    writer.incrementWhitespace();

    writer.writeLine('${className}Impl impl;');
    writer.writeLine();

    for (final observerCollection in privateObserverCollections) {
      writer.writeLine(observerCollection);
    }

    writer.decrementWhitespace();
    writer.writeLine('};');
    writer.writeLine();
  }

  // If there are any sealed subclasses, generate structs for them as well.

  for (final subtype in modelClassInfo.sealedSubclasses) {
    forwardDeclarations.add('struct ${subtype.name};');
    writer.writeLine('struct ${subtype.name} {');
    writer.incrementWhitespace();

    writer.writeLine('using Tag = rfl::Literal<"${subtype.name}">;');
    writer.writeLine();

    for (final MapEntry(key: fieldName, value: fieldInfo)
        in subtype.fields.entries) {
      if (_shouldSkip(fieldInfo.fieldElement)) {
        continue;
      }

      final type = getCppType(fieldInfo.typeInfo, modelClassInfo);
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
    final usingWriter = Writer();

    usingWriter.writeLine(
        'using ${modelClassInfo.annotatedClass.name} = rfl::TaggedUnion<');
    usingWriter.incrementWhitespace();
    usingWriter.writeLine('"__type",');

    for (var i = 0; i < modelClassInfo.sealedSubclasses.length; i++) {
      final subtype = modelClassInfo.sealedSubclasses[i];
      final isLast = i == modelClassInfo.sealedSubclasses.length - 1;

      usingWriter.writeLine('${subtype.name}${isLast ? '' : ','}');
    }

    usingWriter.decrementWhitespace();
    usingWriter.writeLine('>;');

    usingWriter.writeLine();

    usingDirectives.add(usingWriter.result);
  }

  return (
    code: writer.result,
    forwardDeclarations: forwardDeclarations,
    usingDirectives: usingDirectives,
    cppFileImports: cppFileImports,
    functionDefinitions: functionDefinitions,
  );
}

/// Used to generate the imports for a C++ module file.
///
/// See documentation on [GenerateCppModuleFile] for context.
({List<String> forwardDeclarations, List<String> imports})
    _generateCppModuleFile(LibraryReader libraryReader) {
  final forwardDeclarations = <String>[];
  final imports = <String>[];

  final library = libraryReader.element;

  for (final export in library.libraryExports
      .where((export) => export.uri is DirectiveUriWithRelativeUriString)) {
    final uri = export.uri as DirectiveUriWithRelativeUriString;

    // If this export isn't a dart file for some reason, don't try to parse it
    if (!uri.relativeUriString.endsWith('.dart')) {
      continue;
    }

    // Don't try to parse this if the exported library can't be resolved
    if (export.exportedLibrary == null) {
      continue;
    }

    final exportLibraryReader = LibraryReader(export.exportedLibrary!);

    // If the exported library doesn't have any Anthem model classes, then we
    // don't generate an import for it
    bool hasAnyAnthemModel = false;

    for (final classElement in exportLibraryReader.classes) {
      if (hasAnyAnthemModel) break;

      final annotation = const TypeChecker.fromRuntime(AnthemModel)
          .firstAnnotationOf(classElement);

      if (annotation == null) {
        continue;
      }

      final generateCpp =
          annotation.getField('generateCpp')?.toBoolValue() ?? false;

      if (generateCpp) {
        hasAnyAnthemModel = true;
      }
    }

    for (final enumElement in exportLibraryReader.enums) {
      if (hasAnyAnthemModel) break;

      final annotation = const TypeChecker.fromRuntime(AnthemEnum)
          .firstAnnotationOf(enumElement);

      if (annotation == null) {
        continue;
      }

      hasAnyAnthemModel = true;
    }

    if (!hasAnyAnthemModel) {
      continue;
    }

    var cppFile =
        uri.relativeUriString.substring(0, uri.relativeUriString.length - 5);

    imports.add('#include "$cppFile.h"');
  }

  return (forwardDeclarations: forwardDeclarations, imports: imports);
}

/// Checks if a field should be skipped when generating C++ code, based on the
/// @Hide annotation.
bool _shouldSkip(FieldElement field) {
  final hideAnnotation =
      const TypeChecker.fromRuntime(Hide).firstAnnotationOf(field);

  final hide = Hide(
    cpp: hideAnnotation?.getField('cpp')?.toBoolValue() ?? false,
  );

  return hide.cpp;
}
