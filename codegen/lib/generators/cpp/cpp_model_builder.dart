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
import 'package:anthem_codegen/include.dart';
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

    final inputId = buildStep.inputId;
    if (inputId.extension != '.dart') return;

    final LibraryElement library;
    try {
      library = await buildStep.resolver.libraryFor(inputId);
    } catch (ex) {
      return;
    }

    final libraryReader = LibraryReader(library);

    final imports = <String>[];
    final forwardDeclarations = <String>[];
    final usingDirectives = <String>[];
    final moduleFileImports = <String>[]; // See note below
    final codeBlocks = <String>[];
    final functionDefinitions = <String>[];

    // Note that module file imports are only used for module files. There is a
    // detailed description in the doc comment on the @GenerateCppModuleFile
    // annotation.

    // Checks the imports of this library for any that themselves contain Anthem
    // models, and generates the appropriate imports for the C++ module file.
    for (final importElement in library.libraryImports) {
      final importLibrary = importElement.importedLibrary;

      if (importLibrary == null) {
        continue;
      }

      final importLibraryReader = LibraryReader(importLibrary);

      bool hasAnyAnthemModel = false;

      for (final classElement in importLibraryReader.classes) {
        final annotation = const TypeChecker.fromRuntime(AnthemModel)
            .firstAnnotationOf(classElement);

        if (annotation == null) {
          continue;
        }

        final generateCpp =
            annotation.getField('generateCpp')?.toBoolValue() ?? false;

        if (generateCpp) {
          hasAnyAnthemModel = true;
          break;
        }
      }

      for (final enumElement in importLibraryReader.enums) {
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

      final uri = importElement.uri;
      if (uri is DirectiveUriWithLibrary) {
        final pathStr = uri.relativeUri
            .toString()
            .replaceFirst('.dart', '.h')
            .replaceFirst('package:anthem/', 'generated/lib/');
        imports.add('#include "$pathStr"');
      }
    }

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

      if (modelClassInfo.annotation!.generateModelSync) {
        // The model sync code needs ModelUpdateRequest, which comes from the
        // messaging model
        imports.add('#include "messages/messages.h"');
      }

      codeBlocks.add('// ${modelClassInfo.annotatedClass.name}\n\n');

      // Generate the code for this class
      final (
        code: structsCode,
        forwardDeclarations: structsForwardDeclarations,
        usingDirectives: structUsingDirectives,
        functionDefinitions: structFunctionDefinitions,
      ) = _generateStructsForModel(modelClassInfo);

      codeBlocks.add(structsCode);
      forwardDeclarations.addAll(structsForwardDeclarations);
      usingDirectives.addAll(structUsingDirectives);
      functionDefinitions.addAll(structFunctionDefinitions);

      codeBlocks.add('\n\n\n');
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
        functionDefinitions.isEmpty) {
      return;
    }

    var headerCodeToWrite = '''/*
  This file is generated by the Anthem code generator.
*/

#pragma once

#include <rfl/json.hpp>
#include <rfl.hpp>

''';

    var cppCodeToWrite = '''/*
  This file is generated by the Anthem code generator.
*/

#include "${inputId.pathSegments.last.replaceAll('.dart', '.h')}"

''';

    for (final import in imports) {
      headerCodeToWrite += import;
      headerCodeToWrite += '\n';
    }

    headerCodeToWrite += '\n';

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
      final cppAssetIdInEngine =
          AssetId(cppAssetId.package, 'engine/src/generated/${cppAssetId.path}');
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
  List<String> functionDefinitions
}) _generateStructsForModel(ModelClassInfo modelClassInfo) {
  final forwardDeclarations = <String>[];
  final usingDirectives = <String>[];
  final functionDefinitions = <String>[];
  final writer = Writer();

  var baseText = '';

  if (modelClassInfo.isSealed) {
    baseText = 'Base';
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

    final type = getCppType(fieldInfo.typeInfo);
    writer.writeLine('$type $fieldName;');
  }

  writer.writeLine();

  if (modelClassInfo.annotation?.generateModelSync == true) {
    writeModelSyncFnDeclaration(writer);
    functionDefinitions.add(getModelSyncFn(modelClassInfo));
  }

  writer.decrementWhitespace();
  writer.writeLine('};');
  writer.writeLine();

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

      final type = getCppType(fieldInfo.typeInfo);
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
      final annotation = const TypeChecker.fromRuntime(AnthemModel)
          .firstAnnotationOf(classElement);

      if (annotation == null) {
        continue;
      }

      final generateCpp =
          annotation.getField('generateCpp')?.toBoolValue() ?? false;

      if (generateCpp) {
        hasAnyAnthemModel = true;

        // Add forward declaration
        forwardDeclarations.add('struct ${classElement.name};');
      }
    }

    for (final enumElement in exportLibraryReader.enums) {
      final annotation = const TypeChecker.fromRuntime(AnthemEnum)
          .firstAnnotationOf(enumElement);

      if (annotation == null) {
        continue;
      }

      hasAnyAnthemModel = true;

      // Add forward declaration
      forwardDeclarations.add('enum class ${enumElement.name};');
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
