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

import 'package:mobx/mobx.dart';

import 'package:anthem_codegen/include.dart';

/// Serializes a model value to a JSON-serializable object.
///
/// This will take values of a few types, including Anthem models, and turn them
/// into objects that can be serialized to JSON. For simple values:
/// - `String` -> `String`
/// - `int` -> `int`
/// - `bool` -> `bool` etc...
///
/// For enums, it will return the name of the enum as a string.
///
/// For Anthem models, it will call `toJson()` on the model, which will give
/// back a map, or a list if the model is an AnthemObservableList.
Object? _serializeValue(Object? value, {required bool includeFieldsForEngine}) {
  if (value is String) {
    return value;
  } else if (value is int) {
    return value;
  } else if (value is double) {
    return value;
  } else if (value is bool) {
    return value;
  } else if (value is Enum) {
    return value.name;
  } else if (value is AnthemModelBase) {
    return value.toJson(includeFieldsForEngine: includeFieldsForEngine);
  } else if (value == null) {
    return null;
  } else {
    throw ArgumentError('Unsupported type: ${value.runtimeType}');
  }
}

class AnthemObservableList<T> extends ObservableList<T> with AnthemModelBase {
  @override
  AnthemObservableList({super.context, super.name}) : super() {
    _init();
  }

  @override
  AnthemObservableList.of(super.elements, {super.context, super.name})
      : super.of() {
    _init();
  }

  void _init() {
    for (var i = 0; i < length; i++) {
      _setParentPropertiesOnIndex(i);
    }

    observe((change) {
      int? firstChangedIndex;

      if (change.elementChanges != null) {
        for (final elementChange in change.elementChanges!) {
          final accessorChain = [
            FieldAccessor(
              fieldType: FieldType.list,
              index: elementChange.index,
            ),
          ];

          if (elementChange.type == OperationType.add) {
            firstChangedIndex = elementChange.index;

            notifyFieldChanged(
              operation: ListInsert(
                value: _serializeValue(elementChange.newValue,
                    includeFieldsForEngine: true),
              ),
              accessorChain: accessorChain,
            );
          } else if (elementChange.type == OperationType.remove) {
            notifyFieldChanged(
              operation: ListRemove(),
              accessorChain: accessorChain,
            );
          } else if (elementChange.type == OperationType.update) {
            notifyFieldChanged(
              operation: ListUpdate(
                value: _serializeValue(elementChange.newValue,
                    includeFieldsForEngine: true),
              ),
              accessorChain: accessorChain,
            );
          }
        }
      }

      if (firstChangedIndex != null) {
        for (var i = firstChangedIndex; i < length; i++) {
          _setParentPropertiesOnIndex(i);
        }
      }
    });
  }

  void _setParentPropertiesOnIndex(int index) {
    final element = elementAt(index);
    if (element is! AnthemModelBase) {
      return;
    }

    element.setParentProperties(
      parent: this,
      fieldType: FieldType.list,
      index: index,
    );
  }

  @override
  List<Object?> toJson({bool includeFieldsForEngine = false}) {
    return map(
      (e) => _serializeValue(e, includeFieldsForEngine: includeFieldsForEngine),
    ).toList();
  }
}

class AnthemObservableMap<K, V> extends ObservableMap<K, V>
    with AnthemModelBase {
  AnthemObservableMap({super.context, super.name}) : super() {
    _init();
  }

  AnthemObservableMap.of(super.entries, {super.context, super.name})
      : super.of() {
    _init();
  }

  void _init() {
    for (final key in keys) {
      _setParentPropertiesOnValue(key);
    }

    observe((change) {
      final accessorChain = [
        FieldAccessor(
          fieldType: FieldType.map,
          key: change.key,
        ),
      ];

      if (change.type == OperationType.add ||
          change.type == OperationType.update) {
        notifyFieldChanged(
          operation: MapPut(
              value: _serializeValue(change.newValue,
                  includeFieldsForEngine: true)),
          accessorChain: accessorChain,
        );

        if (change.newValue is AnthemModelBase && change.key is K) {
          _setParentPropertiesOnValue(change.key as K);
        }
      } else if (change.type == OperationType.remove) {
        notifyFieldChanged(
          operation: MapRemove(),
          accessorChain: accessorChain,
        );
      }
    });
  }

  void _setParentPropertiesOnValue(K key) {
    final value = this[key];
    if (value is! AnthemModelBase) {
      return;
    }

    value.setParentProperties(
      parent: this,
      fieldType: FieldType.map,
      key: key,
    );
  }

  @override
  Map<Object?, Object?> toJson({bool includeFieldsForEngine = false}) {
    return map(
      (key, value) => MapEntry(
        _serializeValue(key, includeFieldsForEngine: includeFieldsForEngine),
        _serializeValue(value, includeFieldsForEngine: includeFieldsForEngine),
      ),
    );
  }
}
