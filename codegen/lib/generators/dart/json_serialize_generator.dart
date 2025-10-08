/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

import 'package:analyzer/dart/element/element.dart';
import 'package:anthem_codegen/include.dart';
import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:source_gen/source_gen.dart';

import '../util/model_class_info.dart';
import 'serialize_generators.dart';

/// Generates JSON serialization for an Anthem model class.
///
/// We use this over built-in serialization techniques because it allows us to
/// handle special cases more elegantly. Before, MobX observable collections
/// needed to have bespoke serializers and deserializers defined, which were
/// difficult to write and to read.
String generateJsonSerializationCode({required ModelClassInfo context}) {
  var result = StringBuffer();

  result.write('''// ignore: duplicate_ignore
// ignore: non_constant_identifier_names
${(context.annotation?.generateModelSync == true) ? '@override' : ''}
Map<String, dynamic> toJson({bool forEngine = false, bool forProjectFile = true}) {
  final map = <String, dynamic>{};
''');

  for (final entry in context.fields.entries) {
    final name = entry.key;
    final fieldInfo = entry.value;

    if (fieldInfo.isModelConstant) {
      continue;
    }

    final fieldBehavior = _getFieldBehavior(fieldInfo.fieldElement);

    if (fieldBehavior == _FieldBehavior.skip) {
      continue;
    }

    if (fieldBehavior == _FieldBehavior.serializeForEngineOnly) {
      result.write('if (forEngine) {\n');
    }

    if (fieldBehavior == _FieldBehavior.serializeForProjectOnly) {
      result.write('if (forProjectFile) {\n');
    }

    result.write(
      _createSetterForField(
        type: fieldInfo.typeInfo,
        fieldName: name,
        mapName: 'map',
      ),
    );

    if (fieldBehavior == _FieldBehavior.serializeForEngineOnly) {
      result.write('}\n');
    }

    if (fieldBehavior == _FieldBehavior.serializeForProjectOnly) {
      result.write('}\n');
    }
  }

  if (context.isSealed) {
    var isFirst = true;
    for (final subclass in context.sealedSubclasses) {
      if (isFirst) {
        result.write('if (this is ${subclass.name}) {\n');
        isFirst = false;
      } else {
        result.write('else if (this is ${subclass.name}) {\n');
      }

      // For sealed classes, we use the name of the subclass to inform a field
      // in the JSON map. This allows us to determine the correct type when
      // deserializing.
      result.write('map[\'__type\'] = \'${subclass.name}\';\n');

      // Then, we output code to determine which fields to serialize depending
      // on the current subtype.
      for (final field in subclass.fields.entries) {
        final name = field.key;
        final fieldInfo = field.value;

        if (fieldInfo.isModelConstant) {
          continue;
        }

        final fieldBehavior = _getFieldBehavior(fieldInfo.fieldElement);

        if (fieldBehavior == _FieldBehavior.skip) {
          continue;
        }

        if (fieldBehavior == _FieldBehavior.serializeForEngineOnly) {
          result.write('if (forEngine) {\n');
        }

        if (fieldBehavior == _FieldBehavior.serializeForProjectOnly) {
          result.write('if (forProjectFile) {\n');
        }

        result.write(
          _createSetterForField(
            type: fieldInfo.typeInfo,
            fieldName: name,
            accessor: '(this as ${subclass.name}).$name',
            mapName: 'map',
          ),
        );

        if (fieldBehavior == _FieldBehavior.serializeForEngineOnly) {
          result.write('}\n');
        }

        if (fieldBehavior == _FieldBehavior.serializeForProjectOnly) {
          result.write('}\n');
        }
      }

      result.write('}\n');
    }
  }

  result.write('''
  return map;
}
''');

  // Generate deserialization

  return result.toString();
}

enum _FieldBehavior {
  skip,
  alwaysSerialize,
  serializeForEngineOnly,
  serializeForProjectOnly,
}

/// Gets the behavior of a field in the context of JSON serialization. This is
/// based on the @Hide annotation. The options are:
/// - skip: The field should not be serialized
/// - alwaysSerialize: The field should always be serialized
/// - serializeForEngineOnly: The field should be serialized only when sending
///   the model to the engine
_FieldBehavior _getFieldBehavior(FieldElement field) {
  final hideAnnotation = const TypeChecker.typeNamed(
    Hide,
    inPackage: 'anthem_codegen',
  ).firstAnnotationOf(field);

  if (hideAnnotation == null) return _FieldBehavior.alwaysSerialize;

  final hide = Hide(
    serialization:
        hideAnnotation.getField('serialization')?.toBoolValue() ?? false,
    cpp: hideAnnotation.getField('cpp')?.toBoolValue() ?? false,
  );

  if (!hide.cpp && hide.serialization) {
    return _FieldBehavior.serializeForEngineOnly;
  } else if (!hide.cpp && !hide.serialization) {
    return _FieldBehavior.alwaysSerialize;
  } else if (hide.cpp && !hide.serialization) {
    return _FieldBehavior.serializeForProjectOnly;
  }

  return _FieldBehavior.skip;
}

String _createSetterForField({
  required ModelType type,
  required String fieldName,
  String? accessor,
  required String mapName,
}) {
  accessor ??= fieldName;

  var converter = createSerializerForField(type: type, accessor: accessor);

  // If the field is nullable, we need to check if the value we're adding to the
  // JSON map is null before adding it
  if (type.isNullable) {
    // Fix conflict with "value" local variable below
    if (converter == 'value') {
      converter = 'this.value';
    }

    return '''{
    final value = $converter;
    if (value != null) {
      $mapName['$fieldName'] = value;
    }
  }
''';
  }

  return "$mapName['$fieldName'] = $converter;\n";
}
