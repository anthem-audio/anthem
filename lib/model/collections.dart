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

import 'package:mobx/mobx.dart';

import 'anthem_model_base_mixin.dart';

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
Object? _serializeValue(
  Object? value, {
  required bool forEngine,
  required bool forProjectFile,
}) {
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
    return value.toJson(forEngine: forEngine, forProjectFile: forProjectFile);
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
    observe((change) {
      if (change.elementChanges != null) {
        for (final elementChange in change.elementChanges!) {
          final accessorChain = [
            FieldAccessor(
              fieldType: FieldType.list,
              index: elementChange.index,
            ),
          ];

          if (elementChange.type == OperationType.add) {
            final firstChangedIndex = elementChange.index;
            for (var i = firstChangedIndex; i < length; i++) {
              _setParentPropertiesOnIndex(i);
            }

            notifyFieldChanged(
              operation: ListInsert(
                value: elementChange.newValue,
                valueSerialized: _serializeValue(
                  elementChange.newValue,
                  forEngine: true,
                  forProjectFile: false,
                ),
              ),
              accessorChain: accessorChain,
            );
          } else if (elementChange.type == OperationType.remove) {
            final firstChangedIndex = elementChange.index;
            for (var i = firstChangedIndex; i < length; i++) {
              _setParentPropertiesOnIndex(i);
            }

            notifyFieldChanged(
              operation: ListRemove(removedValue: elementChange.oldValue),
              accessorChain: accessorChain,
            );
          } else if (elementChange.type == OperationType.update) {
            _setParentPropertiesOnIndex(elementChange.index);

            notifyFieldChanged(
              operation: ListUpdate(
                oldValue: elementChange.oldValue,
                newValue: elementChange.newValue,
                newValueSerialized: _serializeValue(
                  elementChange.newValue,
                  forEngine: true,
                  forProjectFile: false,
                ),
              ),
              accessorChain: accessorChain,
            );
          }
        }
      }
    });
  }

  void _setParentPropertiesOnIndex(int index) {
    final element = elementAt(index);
    if (element is! AnthemModelBase) {
      return;
    }

    // If the parent is null, then we can't attach parent properties yet. When
    // this model itself is attached, then setParentPropertiesOnChildren will be
    // called which will attach children.
    if (parent == null) {
      return;
    }

    element.setParentProperties(
      parent: this,
      fieldType: FieldType.list,
      index: index,
    );
  }

  @override
  void setParentPropertiesOnChildren() {
    for (var i = 0; i < length; i++) {
      _setParentPropertiesOnIndex(i);
    }
  }

  @override
  List<Object?> toJson({bool forEngine = false, bool forProjectFile = true}) {
    return map(
      (e) => _serializeValue(
        e,
        forEngine: forEngine,
        forProjectFile: forProjectFile,
      ),
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
    observe((change) {
      final accessorChain = [
        FieldAccessor(fieldType: FieldType.map, key: change.key),
      ];

      if (change.type == OperationType.add ||
          change.type == OperationType.update) {
        notifyFieldChanged(
          operation: MapPut(
            oldValue: change.oldValue,
            newValue: change.newValue,
            newValueSerialized: _serializeValue(
              change.newValue,
              forEngine: true,
              forProjectFile: false,
            ),
          ),
          accessorChain: accessorChain,
        );

        if (change.newValue is AnthemModelBase && change.key is K) {
          _setParentPropertiesOnValue(change.key as K);
        }
      } else if (change.type == OperationType.remove) {
        notifyFieldChanged(
          operation: MapRemove(removedValue: change.oldValue),
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

    // If the parent is null, then we can't attach parent properties yet. When
    // this model itself is attached, then setParentPropertiesOnChildren will be
    // called which will attach children.
    if (parent == null) {
      return;
    }

    value.setParentProperties(parent: this, fieldType: FieldType.map, key: key);
  }

  @override
  void setParentPropertiesOnChildren() {
    for (final key in keys) {
      _setParentPropertiesOnValue(key);
    }
  }

  @override
  Map<Object?, Object?> toJson({
    bool forEngine = false,
    bool forProjectFile = true,
  }) {
    return map(
      (key, value) => MapEntry(
        _serializeValue(
          key,
          forEngine: forEngine,
          forProjectFile: forProjectFile,
        ),
        _serializeValue(
          value,
          forEngine: forEngine,
          forProjectFile: forProjectFile,
        ),
      ),
    );
  }
}
