/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

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
          _handleElementChange(elementChange);
        }
      }

      if (change.rangeChanges != null) {
        for (final rangeChange in change.rangeChanges!) {
          _handleRangeChange(rangeChange);
        }
      }
    });
  }

  void _handleElementChange(dynamic elementChange) {
    if (elementChange.type == OperationType.add) {
      _refreshParentPropertiesFrom(elementChange.index);
      _notifyListInsert(elementChange.index, elementChange.newValue);
    } else if (elementChange.type == OperationType.remove) {
      final oldValue = elementChange.oldValue;

      if (oldValue is AnthemModelBase) {
        oldValue.detach();
      }

      _refreshParentPropertiesFrom(elementChange.index);
      _notifyListRemove(elementChange.index, oldValue);
    } else if (elementChange.type == OperationType.update) {
      final oldValue = elementChange.oldValue;
      final newValue = elementChange.newValue;

      if (oldValue is AnthemModelBase) {
        oldValue.parent = null;
      }

      _setParentPropertiesOnIndex(elementChange.index);
      _notifyListUpdate(elementChange.index, oldValue, newValue);
    }
  }

  void _handleRangeChange(dynamic rangeChange) {
    final oldValues = (rangeChange.oldValues as List<T>?) ?? <T>[];
    final newValues = (rangeChange.newValues as List<T>?) ?? <T>[];

    for (final oldValue in oldValues) {
      if (oldValue is AnthemModelBase) {
        oldValue.detach();
      }
    }

    _refreshParentPropertiesFrom(rangeChange.index);

    for (final oldValue in oldValues) {
      _notifyListRemove(rangeChange.index, oldValue);
    }

    for (var i = 0; i < newValues.length; i++) {
      _notifyListInsert(rangeChange.index + i, newValues[i]);
    }
  }

  void _refreshParentPropertiesFrom(int firstChangedIndex) {
    for (var i = firstChangedIndex; i < length; i++) {
      _setParentPropertiesOnIndex(i);
    }
  }

  void _notifyListInsert(int index, T? value) {
    notifyFieldChanged(
      operation: ListInsert(
        value: value,
        valueSerialized: _serializeValue(
          value,
          forEngine: true,
          forProjectFile: false,
        ),
      ),
      accessorChain: [FieldAccessor(fieldType: FieldType.list, index: index)],
    );
  }

  void _notifyListRemove(int index, T? oldValue) {
    notifyFieldChanged(
      operation: ListRemove(removedValue: oldValue),
      accessorChain: [FieldAccessor(fieldType: FieldType.list, index: index)],
    );
  }

  void _notifyListUpdate(int index, T? oldValue, T? newValue) {
    notifyFieldChanged(
      operation: ListUpdate(
        oldValue: oldValue,
        newValue: newValue,
        newValueSerialized: _serializeValue(
          newValue,
          forEngine: true,
          forProjectFile: false,
        ),
      ),
      accessorChain: [FieldAccessor(fieldType: FieldType.list, index: index)],
    );
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
        final oldValue = change.oldValue;
        final newValue = change.newValue;

        if (oldValue is AnthemModelBase) {
          oldValue.detach();
        }

        if (newValue is AnthemModelBase && change.key is K) {
          _setParentPropertiesOnValue(change.key as K);
        }

        notifyFieldChanged(
          operation: MapPut(
            oldValue: oldValue,
            newValue: newValue,
            newValueSerialized: _serializeValue(
              newValue,
              forEngine: true,
              forProjectFile: false,
            ),
          ),
          accessorChain: accessorChain,
        );
      } else if (change.type == OperationType.remove) {
        final oldValue = change.oldValue;

        if (oldValue is AnthemModelBase) {
          oldValue.detach();
        }

        notifyFieldChanged(
          operation: MapRemove(removedValue: oldValue),
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
