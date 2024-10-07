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

/// Represents a type of field in the model.
enum FieldType {
  raw,
  list,
  map,
}

/// Represents a field in a model.
class FieldAccessor {
  final String fieldName;
  final FieldType fieldType;
  final int? index;
  final dynamic key;

  FieldAccessor(this.fieldName, this.fieldType, {this.index, this.key});
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
  AnthemModelBase? _parent;

  /// The type of field that this model is in (raw, list, or map).
  FieldType? _parentFieldType;

  /// The index of this model, if it's in a list.
  int? _parentListIndex;

  /// The key of this model, if it's in a map.
  dynamic _parentMapKey;

  /// The field that this model is in. If this model is in a collection, this
  /// will be the name of the field that the collection is in.
  String? _parentFieldName;

  /// Listeners that are notified when a field is changed.
  final List<void Function(Iterable<FieldAccessor> accessors)> _listeners = [];

  void notifyFieldChanged({
    required List<FieldAccessor> accessors,
    required String fieldName,
    required FieldType fieldType,
    int? index,
    dynamic key,
  }) {
    accessors.add(FieldAccessor(fieldName, fieldType, index: index, key: key));

    for (final listener in _listeners) {
      listener(accessors.reversed);
    }

    if (_parent != null) {
      _parent!.notifyFieldChanged(
        accessors: accessors,
        fieldName: _parentFieldName!,
        fieldType: _parentFieldType!,
        index: _parentListIndex,
        key: _parentMapKey,
      );
    }
  }

  /// Adds a listener that is notified when a field is changed.
  void addFieldChangedListener(
      void Function(Iterable<FieldAccessor> accessors) listener) {
    _listeners.add(listener);
  }

  /// Removes a listener that is notified when a field is changed.
  void removeFieldChangedListener(
      void Function(Iterable<FieldAccessor> accessors) listener) {
    _listeners.remove(listener);
  }

  /// Sets properties that describe the position of this model on its parent
  /// model.
  void setParentProperties({
    required AnthemModelBase parent,
    required FieldType fieldType,
    int? index,
    dynamic key,
    required String parentFieldName,
  }) {
    _parent = parent;
    _parentFieldType = fieldType;
    _parentListIndex = index;
    _parentMapKey = key;
    _parentFieldName = parentFieldName;
  }

  /// Handles updates to a list.
  void handleListUpdate<T>({
    required String fieldName,
    required ObservableList<T> list,
    required ListChange<T> change,
  }) {
    int? resetAfterIndex;

    if (change.elementChanges != null) {
      for (final elementChange in change.elementChanges!) {
        switch (elementChange.type) {
          case OperationType.add:
          case OperationType.remove:
            if (resetAfterIndex == null ||
                resetAfterIndex > elementChange.index) {
              resetAfterIndex = elementChange.index;
            }
          case OperationType.update:
            if (list.nonObservableInner[elementChange.index]
                is AnthemModelBase) {
              (list.nonObservableInner[elementChange.index] as AnthemModelBase)
                  .setParentProperties(
                parent: this,
                parentFieldName: fieldName,
                fieldType: FieldType.list,
                index: elementChange.index,
              );
            }
            break;
        }
      }
    }

    if (change.rangeChanges != null) {
      for (final rangeChange in change.rangeChanges!) {
        if (resetAfterIndex == null || resetAfterIndex > rangeChange.index) {
          resetAfterIndex = rangeChange.index;
        }
      }
    }

    if (resetAfterIndex != null) {
      for (var i = resetAfterIndex; i < list.nonObservableInner.length; i++) {
        if (list.nonObservableInner[i] is AnthemModelBase) {
          (list.nonObservableInner[i] as AnthemModelBase).setParentProperties(
            parent: this,
            parentFieldName: fieldName,
            fieldType: FieldType.list,
            index: i,
          );
        }
      }
    }
  }

  /// Handles updates to a map.
  void handleMapUpdate<K, V>({
    required String fieldName,
    required ObservableMap<K, V> map,
    required MapChange<K, V> change,
  }) {
    if (change.newValue is AnthemModelBase) {
      (change.newValue as AnthemModelBase).setParentProperties(
        parent: this,
        parentFieldName: fieldName,
        fieldType: FieldType.map,
        key: change.key,
      );
    }
  }
}
