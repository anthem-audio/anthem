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

import 'dart:convert';

import 'package:anthem/model/project.dart';
import 'package:mobx/mobx.dart';

/// Represents a type of field in the model.
enum FieldType { raw, list, map }

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
  final dynamic newValueSerialized;

  /// The value that was replaced, if any.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic oldValue;

  T oldValueAs<T>() => oldValue as T;

  /// The new value of the field.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic newValue;

  T newValueAs<T>() => newValue as T;

  RawFieldUpdate({
    required this.newValueSerialized,
    required this.newValue,
    this.oldValue,
  });

  @override
  String toString() {
    return 'RawFieldUpdate(newValueSerialized (${newValueSerialized.runtimeType}): ${_stringifyValue(newValueSerialized)}, oldValue (${oldValue.runtimeType}): ${_stringifyValue(oldValue)}, newValue (${newValue.runtimeType}): ${_stringifyValue(newValue)})';
  }
}

/// Represents inserting an item in a list
class ListInsert extends FieldOperation {
  /// This is the value to be inserted. It is a serialized representation.
  ///
  /// See above for the types that this can be.
  final dynamic valueSerialized;

  /// The value to be inserted.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic value;

  T valueAs<T>() => value as T;

  ListInsert({required this.valueSerialized, required this.value});

  @override
  String toString() {
    return 'ListInsert(valueSerialized: ${_stringifyValue(valueSerialized)}, value (${value.runtimeType}): ${_stringifyValue(value)})';
  }
}

/// Represents removing an item from a list
class ListRemove extends FieldOperation {
  ListRemove({required this.removedValue});

  /// The value to be removed.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic removedValue;

  T removedValueAs<T>() => removedValue as T;

  @override
  String toString() {
    return 'ListRemove(removedValue (${removedValue.runtimeType}): ${_stringifyValue(removedValue)})';
  }
}

/// Represents updating an item in a list
class ListUpdate extends FieldOperation {
  /// This is the new value of the field. It is a serialized representation.
  ///
  /// See above for the types that this can be.
  final dynamic newValueSerialized;

  /// The value that was replaced, if any.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic oldValue;

  T oldValueAs<T>() => oldValue as T;

  /// The new value of the field.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic newValue;

  T newValueAs<T>() => newValue as T;

  ListUpdate({
    required this.newValueSerialized,
    required this.oldValue,
    required this.newValue,
  });

  @override
  String toString() {
    return 'ListUpdate(newValueSerialized (${newValueSerialized.runtimeType}): ${_stringifyValue(newValueSerialized)}, oldValue (${oldValue.runtimeType}): ${_stringifyValue(oldValue)}, newValue (${newValue.runtimeType}): ${_stringifyValue(newValue)})';
  }
}

/// Represents inserting or replacing an item in a map.
class MapPut extends FieldOperation {
  /// This is the new value of the field. It is a serialized representation.
  ///
  /// See above for the types that this can be.
  final dynamic newValueSerialized;

  /// The value that was replaced, if any.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic oldValue;

  T oldValueAs<T>() => oldValue as T;

  /// The value to be inserted.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic newValue;

  T newValueAs<T>() => newValue as T;

  MapPut({
    required this.newValueSerialized,
    required this.newValue,
    required this.oldValue,
  });

  @override
  String toString() {
    return 'MapPut(newValueSerialized (${newValueSerialized.runtimeType}): ${_stringifyValue(newValueSerialized)}, newValue (${newValue.runtimeType}): ${_stringifyValue(newValue)}, oldValue (${oldValue.runtimeType}): ${_stringifyValue(oldValue)})';
  }
}

/// Represents removing an item from a map.
class MapRemove extends FieldOperation {
  /// The value that was removed.
  ///
  /// This is the actual value, not a serialized representation.
  final dynamic removedValue;

  MapRemove({required this.removedValue});

  @override
  String toString() {
    return 'MapRemove(removedValue (${removedValue.runtimeType}): ${_stringifyValue(removedValue)})';
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

  @override
  String toString() {
    return 'FieldAccessor(fieldType: $fieldType, fieldName: $fieldName, index: $index, key: $key)';
  }
}

/// A subset of [ListChange] from MobX. Allows us to serialize changes before
/// sending them here.
class AnthemListChange<T> {
  AnthemListChange({this.elementChanges, this.rangeChanges});

  final List<AnthemElementChange<T>>? elementChanges;
  final List<AnthemRangeChange<T>>? rangeChanges;
}

class AnthemElementChange<T> {
  AnthemElementChange({
    required this.index,
    this.type = OperationType.update,
    this.newValueSerialized,
  });

  final int index;
  final OperationType type;
  final T? newValueSerialized;
}

class AnthemRangeChange<T> {
  AnthemRangeChange({
    required this.index,
    this.newValuesSerialized,
    this.numItemsRemoved = 0,
  });

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

  /// The name of the field in the parent model that holds this model. If the
  /// parent model is a collection, this will be null.
  String? parentFieldName;

  /// A write will be reported to tihs atom when this model or any descendant
  /// model is changed.
  final Atom _allChangesAtom = Atom();

  /// If called during a MobX observation, this will cause the widget to rebuild
  /// when any field in this model or any descendant model is changed.
  ///
  /// This observes all updates to the model item and its descendants, but it
  /// does so in a way that is very efficient when the alternative is to observe
  /// a large number of fields (250+).
  ///
  /// Instead of observing every field in every descendant model, it simply
  /// listens for the state change stream that is already filtering up to the
  /// root model item. This state change stream is used for syncing the UI and
  /// engine models, and since it's already there, we get it nearly for free.
  ///
  /// This function should be used in conjunction with [blockObservationBuilder]
  /// to prevent ordinary MobX observables from being observed while building a
  /// given widget tree.
  ///
  /// This is typically less efficient than using MobX like normal, because
  /// Flutter's rebuilds are not free, and so MobX's approach has some runtime
  /// overhead. This overhead is usually less than building large widget trees
  /// often, so it's usually worth it to use MobX to observe individual fields.
  ///
  /// However, when you have a very large number of fields to observe, the
  /// overhead of observing each field becomes much higher than the overhead of
  /// rebuilding an entire widget. As an example, in a naive implementation of
  /// our piano roll using MobX, the piano roll slows down massively when trying
  /// to move around more than a hundred or so notes, and this is directly due
  /// to the overhead of having so many observables. Since we want to redraw the
  /// piano roll when the vast majority of note attributes change, and since our
  /// rebuild is already very efficient, we can afford to observe the entire
  /// notes collection all at once, and it is actually much more efficient to do
  /// so.
  ///
  /// As an example:
  ///
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   someModelItem.observeAllChanges();
  ///
  ///   return blockObservationBuilder(
  ///     modelItem: someModelItem,
  ///     builder: () {
  ///       return Text(someModelItem.someObservableValue.toString());
  ///     },
  ///   );
  /// }
  /// ```
  void observeAllChanges() {
    _allChangesAtom.reportRead();
  }

  int observationBlockDepth = 0;

  /// If this is true, then this model and all descendants will not report
  /// changes to MobX. This is set by [blockObservationBuilder].
  bool get blockDescendantObservations => observationBlockDepth > 0;

  /// Listeners that are notified when a field is changed.
  final List<
    void Function(Iterable<FieldAccessor> accessors, FieldOperation operation)
  >
  _listeners = [];

  /// Serializes the model to a JSON representation.
  dynamic toJson({bool includeFieldsForEngine = false});

  void notifyFieldChanged({
    required FieldOperation operation,
    List<FieldAccessor>? accessorChain,
  }) {
    final accessorChainNotNull = accessorChain ?? [];

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

    // Notify _allChangesAtom that a change has occurred
    _allChangesAtom.reportChanged();
  }

  /// Adds a listener that is notified when a field is changed.
  void addFieldChangedListener(
    void Function(Iterable<FieldAccessor> accessors, FieldOperation operation)
    listener,
  ) {
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

    // setParentProperties() will only be called when the model is added to a
    // parent model or collection. Models really shouldn't be moved around, so
    // we will assume that we can recursively initialize all children too.
    setParentPropertiesOnChildren();

    // Run any attach actions that have been queued up
    for (final action in _onAttachActions) {
      action();
    }
  }

  void setParentPropertiesOnChildren();

  ProjectModel? _project;
  ProjectModel get project {
    if (_project != null) {
      return _project!;
    }

    var model = parent;
    while (model != null) {
      if (model is ProjectModel) {
        _project = model;
        return model;
      }

      model = model.parent;
    }

    throw Exception('Could not find project model');
  }

  /// Gets the first ancestor of this model that is of type [T].
  T getFirstAncestorOfType<T extends AnthemModelBase>() {
    var model = parent;
    while (model != null) {
      if (model is T) {
        return model;
      }

      model = model.parent;
    }

    throw Exception('Could not find ancestor model of type $T');
  }

  final List<void Function()> _onAttachActions = [];

  /// Schedules work to be done when this model is attached to the tree.
  void onModelAttached(void Function() onModelAttached) {
    if (parent != null) {
      throw Exception('Model is already attached');
    }

    _onAttachActions.add(onModelAttached);
  }
}

// This section allows us to short-circuit the check for whether there is an
// active blockObservationBuilder(). There could be nested
// blockObservationBuilders, and if at least one is active, every model
// observation must check if it is within a blocked model. Because of this, we
// globally track whether a blockObservationBuilder is even active, so we can
// avoid the check if it's not.

int _blockObservationBuilderDepth = 0;

void incrementBlockObservationBuilderDepth() {
  _blockObservationBuilderDepth++;
}

void decrementBlockObservationBuilderDepth() {
  _blockObservationBuilderDepth--;
}

bool get isBlockObservationBuilderActive {
  return _blockObservationBuilderDepth > 0;
}
