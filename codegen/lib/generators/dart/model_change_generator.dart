/*
  Copyright (C) 2025 Joshua Wade

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

import 'package:anthem_codegen/generators/util/model_class_info.dart';
import 'package:anthem_codegen/generators/util/model_types.dart';

String generateFilterBuilders({required ModelClassInfo context}) {
  final result = StringBuffer();

  final className = '${context.annotatedClass.name}ModelFilterBuilder';

  result.write('''
    class $className extends GenericModelFilterBuilder {
      $className(super.context);
  ''');

  for (final MapEntry(key: fieldName, value: fieldInfo)
      in context.fields.entries) {
    if (fieldInfo.isModelConstant) {
      continue;
    }

    // If this isn't in the C++ model, then we're not generating change events
    // for it
    if (fieldInfo.hideAnnotation?.cpp == true) {
      continue;
    }

    final getter = switch (fieldInfo.typeInfo) {
      StringModelType() ||
      IntModelType() ||
      DoubleModelType() ||
      NumModelType() ||
      BoolModelType() ||
      EnumModelType() ||
      ColorModelType() =>
        '''
        void get $fieldName {
          context.addNode(ModelFilterFieldNode(fieldName: '$fieldName'));
        }
      ''',
      ListModelType() => _generateListFieldGetter(fieldName, fieldInfo),
      MapModelType() => _generateMapFieldGetter(fieldName, fieldInfo),
      CustomModelType() =>
        '''
        ${fieldInfo.typeInfo.dartName}ModelFilterBuilder get $fieldName {
          context.addNode(ModelFilterFieldNode(
            fieldName: '$fieldName',
          ));
          return ${fieldInfo.typeInfo.dartName}ModelFilterBuilder(context);
        }
      ''',
      UnionModelType() => '',
      UnknownModelType() => throw UnimplementedError(),
    };

    result.write(getter);
  }

  result.write('''
    void get anyField {
      context.addNode(ModelFilterPassthroughNode());
    }
  ''');

  result.write('''
    void multiple(List<void Function($className b)> builders) {
      context.addNode(ModelFilterOrNode(
        builders.map((b) {
          final localContext = ModelFilterBuilderContext();
          final builderClass = $className(localContext);
          b(builderClass);
          return localContext.root ?? ModelFilterPassthroughNode();
        }).toList()
      ));
    }
  ''');

  result.write('}\n');

  return result.toString();
}

String _generateListFieldGetter(String fieldName, ModelFieldInfo fieldInfo) {
  String listType = _generateListType(fieldInfo.typeInfo as ListModelType);
  String tGenerator = _generateListTGenerator(
    fieldInfo.typeInfo as ListModelType,
  );

  return '''
    $listType get $fieldName {
      context.addNode(ModelFilterFieldNode(fieldName: '$fieldName'));
      return $listType(
        context: context,
        tGenerator: $tGenerator,
      );
    }
  ''';
}

String _generateListType(ListModelType typeInfo) {
  final itemType = typeInfo.itemType;

  if (itemType is CustomModelType) {
    return 'ListModelFilterBuilder<${itemType.dartName}ModelFilterBuilder>';
  } else if (itemType is ListModelType) {
    final nestedListType = _generateListType(itemType);
    return 'ListModelFilterBuilder<$nestedListType>';
  } else if (itemType is MapModelType) {
    final nestedMapType = _generateMapType(itemType);
    return 'ListModelFilterBuilder<$nestedMapType>';
  } else if (itemType is StringModelType ||
      itemType is IntModelType ||
      itemType is DoubleModelType ||
      itemType is NumModelType ||
      itemType is BoolModelType ||
      itemType is EnumModelType ||
      itemType is ColorModelType) {
    return 'ListModelFilterBuilder<void>';
  } else {
    throw UnimplementedError();
  }
}

String _generateListTGenerator(ListModelType typeInfo) {
  if (typeInfo.itemType is CustomModelType) {
    final itemType = typeInfo.itemType as CustomModelType;
    return '(context) => ${itemType.dartName}ModelFilterBuilder(context)';
  } else if (typeInfo.itemType is ListModelType) {
    final itemType = typeInfo.itemType as ListModelType;
    final nestedTGenerator = _generateListTGenerator(itemType);
    final nestedListType = _generateListType(itemType);
    return '(context) => $nestedListType(context: context, tGenerator: $nestedTGenerator)';
  } else if (typeInfo.itemType is MapModelType) {
    final itemType = typeInfo.itemType as MapModelType;
    final nestedTGenerator = _generateMapVGenerator(itemType);
    final nestedMapType = _generateMapType(itemType);
    return '(context) => $nestedMapType(context: context, valueGenerator: $nestedTGenerator)';
  } else if (typeInfo.itemType is StringModelType ||
      typeInfo.itemType is IntModelType ||
      typeInfo.itemType is DoubleModelType ||
      typeInfo.itemType is NumModelType ||
      typeInfo.itemType is BoolModelType ||
      typeInfo.itemType is EnumModelType ||
      typeInfo.itemType is ColorModelType) {
    return '(context) {}';
  } else {
    throw UnimplementedError();
  }
}

String _generateMapFieldGetter(String fieldName, ModelFieldInfo fieldInfo) {
  final mapType = fieldInfo.typeInfo as MapModelType;
  final mapTypeName = _generateMapType(mapType);
  final valueGenerator = _generateMapVGenerator(mapType);

  return '''
    $mapTypeName get $fieldName {
      context.addNode(ModelFilterFieldNode(fieldName: '$fieldName'));
      return $mapTypeName(
        context: context,
        valueGenerator: $valueGenerator,
      );
    }
  ''';
}

String _generateMapType(MapModelType typeInfo) {
  final valueType = typeInfo.valueType;

  if (valueType is CustomModelType) {
    return 'MapModelFilterBuilder<${valueType.dartName}ModelFilterBuilder>';
  } else if (valueType is ListModelType) {
    final nestedListType = _generateListType(valueType);
    return 'MapModelFilterBuilder<$nestedListType>';
  } else if (valueType is MapModelType) {
    final nestedMapType = _generateMapType(valueType);
    return 'MapModelFilterBuilder<$nestedMapType>';
  } else if (valueType is StringModelType ||
      valueType is IntModelType ||
      valueType is DoubleModelType ||
      valueType is NumModelType ||
      valueType is BoolModelType ||
      valueType is EnumModelType ||
      valueType is ColorModelType) {
    return 'MapModelFilterBuilder<void>';
  } else {
    throw UnimplementedError();
  }
}

String _generateMapVGenerator(MapModelType typeInfo) {
  final valueType = typeInfo.valueType;

  if (valueType is CustomModelType) {
    return '(context) => ${valueType.dartName}ModelFilterBuilder(context)';
  } else if (valueType is ListModelType) {
    final nestedListType = _generateListType(valueType);
    final nestedTGenerator = _generateListTGenerator(valueType);
    return '(context) => $nestedListType(context: context, tGenerator: $nestedTGenerator)';
  } else if (valueType is MapModelType) {
    final nestedMapType = _generateMapType(valueType);
    final nestedValueGenerator = _generateMapVGenerator(valueType);
    return '(context) => $nestedMapType(context: context, valueGenerator: $nestedValueGenerator)';
  } else if (valueType is StringModelType ||
      valueType is IntModelType ||
      valueType is DoubleModelType ||
      valueType is NumModelType ||
      valueType is BoolModelType ||
      valueType is EnumModelType ||
      valueType is ColorModelType) {
    return '(context) {}';
  } else {
    throw UnimplementedError();
  }
}

String generateOnChangeMethod({required ModelClassInfo context}) {
  final className = context.annotatedClass.name;

  return '''
    ModelFilterSubscription onChange(
      void Function(${className}ModelFilterBuilder b) build,
      void Function(ModelFilterEvent) listener,
    ) {
      final context = ModelFilterBuilderContext();
      final builder = ${className}ModelFilterBuilder(context);
      build(builder);
      final filter = context.root;

      void handler(List<FieldAccessor> fieldAccessors, FieldOperation operation) {
        if (filter != null && filter.matches(fieldAccessors, operation)) {
          listener(
            ModelFilterEvent(
              fieldAccessors: fieldAccessors,
              operation: operation,
            ),
          );
        }
      }

      addRawFieldChangedListener(handler);

      return ModelFilterSubscription(cancel: () {
        removeRawFieldChangedListener(handler);
      });
    }
  ''';
}
