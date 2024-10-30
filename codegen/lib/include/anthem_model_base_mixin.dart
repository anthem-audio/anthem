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

import 'dart:convert';

import 'package:mobx/mobx.dart';

/// Represents a type of field in the model.
enum FieldType {
  raw,
  list,
  map,
}

String _stringifyValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return jsonEncode(value);
  }

  return value?.toString() ?? 'null';
}

/// Represents an operation to a field, map, or list.
sealed class FieldOperation {}

class RawFieldUpdate extends FieldOperation {
  /// This is the new value of the field. It is a serialized representation. It
  /// can be any of the following:
  /// - null
  /// - bool
  /// - int
  /// - double
  /// - String, representing either string or enum
  /// - List
  /// - Map
  ///
  /// It can also be a serialized representation of another Anthem model. This
  /// will also be a map, but instead of representing an actual map collection,
  /// it will be the result of calling `toJson()` on the model.
  final dynamic newValue;

  RawFieldUpdate({required this.newValue});

  @override
  String toString() {
    return 'RawFieldUpdate(newValue: ${_stringifyValue(newValue)})';
  }
}

/// Represents inserting an item in a list
class ListInsert extends FieldOperation {
  final int index;

  /// This is the new value of the field. It is a serialized representation.
  ///
  /// See above for the types that this can be.
  final dynamic value;

  ListInsert({
    required this.index,
    required this.value,
  });

  @override
  String toString() {
    return 'ListInsert(index: $index, value: ${_stringifyValue(value)})';
  }
}

/// Represents removing an item from a list
class ListRemove extends FieldOperation {
  final int index;

  ListRemove({
    required this.index,
  });

  @override
  String toString() {
    return 'ListRemove(index: $index)';
  }
}

/// Represents updating an item in a list
class ListUpdate extends FieldOperation {
  final int index;

  /// This is the new value of the field. It is a serialized representation.
  ///
  /// See above for the types that this can be.
  final dynamic value;

  ListUpdate({
    required this.index,
    required this.value,
  });

  @override
  String toString() {
    return 'ListUpdate(index: $index, value: ${_stringifyValue(value)})';
  }
}

/// Represents inserting or replacing an item in a map.
class MapPut extends FieldOperation {
  /// This is the new value of the field. It is a serialized representation.
  ///
  /// See above for the types that this can be.
  final dynamic value;

  MapPut({
    required this.value,
  });

  @override
  String toString() {
    return 'MapPut(value (${value.runtimeType}): ${_stringifyValue(value)})';
  }
}

/// Represents removing an item from a map.
class MapRemove extends FieldOperation {
  @override
  String toString() {
    return 'MapRemove()';
  }
}

/// Represents a field in a model.
class FieldAccessor {
  final FieldType fieldType;
  final String? fieldName;
  final int? index;
  final dynamic key;

  FieldAccessor({
    required this.fieldType,
    this.fieldName,
    this.index,
    this.key,
  });
}

/// A subset of [ListChange] from MobX. Allows us to serialize changes before
/// sending them here.
class AnthemListChange<T> {
  AnthemListChange({this.elementChanges, this.rangeChanges});

  final List<AnthemElementChange<T>>? elementChanges;
  final List<AnthemRangeChange<T>>? rangeChanges;
}

class AnthemElementChange<T> {
  AnthemElementChange(
      {required this.index,
      this.type = OperationType.update,
      this.newValueSerialized});

  final int index;
  final OperationType type;
  final T? newValueSerialized;
}

class AnthemRangeChange<T> {
  AnthemRangeChange(
      {required this.index,
      this.newValuesSerialized,
      this.numItemsRemoved = 0});

  final int index;
  final List<T>? newValuesSerialized;
  final int numItemsRemoved;
}

/// This mixin defines functionality that Anthem models use.
///
/// This mixin is used to provide functionality for models to communicate up and
/// down the tree. When changes are made in a model, the change can propagate to
/// the engine. This mixin provides functionality that enables the changes from
/// leaf nodes to propagate up the tree to the root node, at which point they
/// can be forwarded to the engine.
///
/// This is used by generated code.
mixin AnthemModelBase {
  /// The parent of this model.
  AnthemModelBase? parent;

  /// The type of field that this model is in (raw, list, or map).
  FieldType? parentFieldType;

  /// The index of this model, if it's in a list.
  int? parentListIndex;

  /// The key of this model, if it's in a map.
  dynamic parentMapKey;

  /// The field that this model is in. If this model is in a collection, this
  /// will be the name of the field that the collection is in.

  String? parentFieldName;

  /// Listeners that are notified when a field is changed.
  final List<
          void Function(
              Iterable<FieldAccessor> accessors, FieldOperation operation)>
      _listeners = [];

  /// Tracks the initialization status of the model. This works in conjunction
  /// with [Hydratable] to ensure that the model is initialized when it is
  /// constructed.
  bool isInitialized = false;

  /// Serializes the model to a JSON representation.
  dynamic toJson({bool includeFieldsForEngine = false});

  void notifyFieldChanged({
    required FieldOperation operation,
    List<FieldAccessor>? accessorChain,
  }) {
    final accessorChainNotNull = accessorChain ?? <FieldAccessor>[];

    for (final listener in _listeners) {
      listener(accessorChainNotNull.reversed, operation);
    }

    // If the parent field is not set, then this model doesn't have a parent yet
    // and so shouldn't try to propagate the change up the tree.
    if (parent == null) {
      return;
    }

    // Add the accessor for this item in the parent model
    accessorChainNotNull.add(
      FieldAccessor(
        fieldType: parentFieldType!,
        fieldName: parentFieldName,
        index: parentListIndex,
        key: parentMapKey,
      ),
    );

    // Propagate the change up the tree
    if (parent != null) {
      parent!.notifyFieldChanged(
        operation: operation,
        accessorChain: accessorChainNotNull,
      );
    }
  }

  /// Adds a listener that is notified when a field is changed.
  void addFieldChangedListener(
      void Function(Iterable<FieldAccessor> accessors, FieldOperation operation)
          listener) {
    _listeners.add(listener);
  }

  /// Removes a listener that is notified when a field is changed.
  void removeFieldChangedListener(
    void Function(Iterable<FieldAccessor> accessors, FieldOperation operation)
        listener,
  ) {
    _listeners.remove(listener);
  }

  /// Sets properties that describe the position of this model on its parent
  /// model.
  void setParentProperties({
    required AnthemModelBase parent,
    required FieldType fieldType,
    int? index,
    dynamic key,
    String? fieldName,
  }) {
    this.parent = parent;
    parentFieldType = fieldType;
    parentListIndex = index;
    parentMapKey = key;
    parentFieldName = fieldName;
  }
}
