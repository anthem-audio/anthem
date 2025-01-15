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
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'model_class_info.dart';

/// Represents a type in the model.
sealed class ModelType {
  abstract final bool canBeMapKey;
  abstract final String dartName;
  final bool isNullable;

  ModelType({required this.isNullable});
}

class StringModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get dartName => 'String';

  StringModelType({required super.isNullable});
}

class IntModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get dartName => 'int';

  IntModelType({required super.isNullable});
}

class DoubleModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get dartName => 'double';

  DoubleModelType({required super.isNullable});
}

class NumModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get dartName => 'num';

  NumModelType({required super.isNullable});
}

class BoolModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get dartName => 'bool';

  BoolModelType({required super.isNullable});
}

class EnumModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  final String enumName;

  final EnumElement enumElement;

  EnumModelType(this.enumName,
      {required super.isNullable, required this.enumElement});

  @override
  String get dartName => enumName;
}

enum CollectionType {
  raw,
  mobXObservable,
  anthemObservable,
}

class ListModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  final CollectionType collectionType;

  /// Defines whether this is a regular list (false) or a MobX ObservableList /
  /// AnthemObservableList (true).
  bool get isObservable => collectionType != CollectionType.raw;

  final ModelType itemType;

  ListModelType(this.itemType,
      {this.collectionType = CollectionType.raw, required super.isNullable});

  @override
  String get dartName {
    final collectionTypeName = switch (collectionType) {
      CollectionType.raw => 'List',
      CollectionType.mobXObservable => 'ObservableList',
      CollectionType.anthemObservable => 'AnthemObservableList',
    };

    return '$collectionTypeName<${itemType.dartName}${itemType.isNullable ? '?' : ''}>';
  }
}

class MapModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  final CollectionType collectionType;

  /// Defines whether this is a regular map (false) or a MobX ObservableMap /
  /// AnthemObservableMap (true).
  bool get isObservable => collectionType != CollectionType.raw;

  final ModelType keyType;
  final ModelType valueType;

  MapModelType(this.keyType, this.valueType,
      {this.collectionType = CollectionType.raw, required super.isNullable});

  @override
  String get dartName {
    final collectionTypeName = switch (collectionType) {
      CollectionType.raw => 'Map',
      CollectionType.mobXObservable => 'ObservableMap',
      CollectionType.anthemObservable => 'AnthemObservableMap',
    };

    return '$collectionTypeName<${keyType.dartName}${keyType.isNullable ? '?' : ''}, ${valueType.dartName}${valueType.isNullable ? '?' : ''}>';
  }
}

class ColorModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  @override
  String get dartName => 'Color';

  ColorModelType({required super.isNullable});
}

/// Represents a custom type that is defined as an Anthem model
class CustomModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  final ModelClassInfo modelClassInfo;

  CustomModelType(this.modelClassInfo, {required super.isNullable});

  @override
  String get dartName => modelClassInfo.annotatedClass.name;
}

class UnionModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  @override
  String get dartName => 'Object';

  final List<ModelType> subTypes;

  UnionModelType(this.subTypes, {required super.isNullable});
}

/// Represents a type that may or may not be valid, but cannot be parsed for
/// some reason.
class UnknownModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  @override
  final String dartName;

  UnknownModelType({required this.dartName, required super.isNullable});
  UnknownModelType.error(
      {this.dartName = 'ErrorType', super.isNullable = false});
}

/// Parses a Dart type into a [ModelType].
ModelType getModelType(
    DartType type, LibraryReader libraryReader, ClassElement annotatedClass,
    {FieldElement? field}) {
  final element = type.element;
  if (element == null) return UnknownModelType.error();

  final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

  return switch (element.name) {
    'bool' => BoolModelType(isNullable: isNullable),
    'int' => IntModelType(isNullable: isNullable),
    'double' => DoubleModelType(isNullable: isNullable),
    'num' => NumModelType(isNullable: isNullable),
    'String' => StringModelType(isNullable: isNullable),
    'Color' => ColorModelType(isNullable: isNullable),
    _ => (() {
        final unionAnnotation = field == null
            ? null
            : const TypeChecker.fromRuntime(Union).firstAnnotationOf(field);

        // Check if this is a list
        if (element is ClassElement &&
            (element.name == 'List' ||
                element.name == 'ObservableList' ||
                element.name == 'AnthemObservableList')) {
          if (type is! ParameterizedType) return UnknownModelType.error();

          final typeParam = type.typeArguments.first;
          if (typeParam.element == null) return UnknownModelType.error();

          final itemType =
              getModelType(typeParam, libraryReader, annotatedClass);
          return ListModelType(
            itemType,
            collectionType: switch (element.name) {
              'ObservableList' => CollectionType.mobXObservable,
              'AnthemObservableList' => CollectionType.anthemObservable,
              _ => CollectionType.raw,
            },
            isNullable: isNullable,
          );
        }

        // Check if this is a map
        if (element is ClassElement &&
            (element.name == 'Map' ||
                element.name == 'ObservableMap' ||
                element.name == 'AnthemObservableMap')) {
          if (type is! ParameterizedType) return UnknownModelType.error();

          final typeParams = type.typeArguments;
          if (typeParams.length != 2) return UnknownModelType.error();

          final keyType =
              getModelType(typeParams[0], libraryReader, annotatedClass);
          if (!keyType.canBeMapKey) {
            log.warning(
                'Map key type cannot be used as a map key: ${typeParams[0].element?.name}');
            log.warning(
                '${typeParams[0].element?.name} is a field on ${annotatedClass.name}.');
            return UnknownModelType.error();
          }

          final valueType =
              getModelType(typeParams[1], libraryReader, annotatedClass);
          return MapModelType(
            keyType,
            valueType,
            collectionType: switch (element.name) {
              'ObservableMap' => CollectionType.mobXObservable,
              'AnthemObservableMap' => CollectionType.anthemObservable,
              _ => CollectionType.raw,
            },
            isNullable: isNullable,
          );
        }

        // Check for Object with @Union() annotation
        else if (element is ClassElement && element.name == 'Object') {
          final types = unionAnnotation
              ?.getField('types')
              ?.toListValue()
              ?.map((e) => e.toTypeValue())
              .whereType<DartType>()
              .toList();

          final subTypeModelTypes = types
              ?.map((e) => getModelType(e, libraryReader, annotatedClass))
              .toList();

          if (subTypeModelTypes != null) {
            return UnionModelType(subTypeModelTypes, isNullable: isNullable);
          }
        } else if (unionAnnotation != null && field != null) {
          throw Exception(
              'Union annotation must be used on Object type, but was used on ${element.name}. The type ${element.name} is used in a field on ${annotatedClass.name}.');
        }

        // Check for custom type
        else if (element is ClassElement) {
          // If this is a custom type, it should be annotated as an Anthem model
          final anthemModelAnnotation =
              const TypeChecker.fromRuntime(AnthemModel)
                  .firstAnnotationOf(element);
          if (anthemModelAnnotation == null) {
            return UnknownModelType(
                dartName: element.name, isNullable: isNullable);
          }

          try {
            final type = ModelClassInfo(libraryReader, element);
            return CustomModelType(type, isNullable: isNullable);
          } catch (e) {
            log.warning('Error parsing custom type: ${element.name}');
            log.warning(
                'This may be because the type is not formed correctly.');
            log.warning(
                '${element.name} is a field on ${annotatedClass.name}.');
            return UnknownModelType(
                dartName: element.name, isNullable: isNullable);
          }
        }

        // Check for enum
        else if (element is EnumElement) {
          return EnumModelType(element.name,
              isNullable: isNullable, enumElement: element);
        }

        log.warning(
            'Unknown type: ${element.name}. This is not expected, and may be a bug. The type ${element.name} is used in a field on ${annotatedClass.name}.');

        return UnknownModelType.error();
      })(),
  };
}
