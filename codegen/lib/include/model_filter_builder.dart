/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

/// This class and its subclasses are used to build filters for model change
/// streams.
///
/// The filter is represented as a tree of [ModelFilterNode]s. This tree can
/// be matched against a given model change to either include or exclude it from
/// the stream.
///
/// A tree is built using a [GenericModelFilterBuilder], which is surfaced to model
/// consumers via the generated onChange method in each model class.
sealed class ModelFilterNode {
  /// Generically chains [next] to follow this node in the tree, as the matcher
  /// for the next level down.
  ///
  /// For nodes that can have multiple children (e.g. [ModelFilterOrNode]), this
  /// may be called multiple times to add multiple children.
  void chain(ModelFilterNode next);

  /// Replaces the next node in the chain with [next].
  ///
  /// This is used to wrap existing nodes with modifier nodes, such as
  /// [ModelFilterChangeTypeModifierNode].
  void replaceNext(ModelFilterNode next);

  /// Matches this node and its children against a given change path.
  ModelFilterMatch match(
    Iterable<FieldAccessor> accessors,
    FieldOperation operation,
  );

  /// Allows the terminal node in this subtree to match descendant paths.
  void allowDescendants();
}

/// Bindings captured while matching a model filter against a model change.
class ModelChangeBindings {
  final Map<String, dynamic> _values;

  ModelChangeBindings(Map<String, dynamic> values)
    : _values = Map.unmodifiable(values);

  T get<T>(String key) => _values[key] as T;

  T? maybeGet<T>(String key) => _values[key] as T?;

  bool containsKey(String key) => _values.containsKey(key);

  dynamic operator [](String key) => _values[key];

  Map<String, dynamic> get asMap => _values;
}

/// The result of matching a model filter against a model change.
typedef ModelFilterMatch = ({bool matches, Map<String, dynamic> bindings});

const ModelFilterMatch _noModelFilterMatch = (
  matches: false,
  bindings: <String, dynamic>{},
);

dynamic _changedValueForOperation(FieldOperation operation) {
  if (operation.hasNewValue) {
    return operation.newValue;
  }

  return operation.oldValue;
}

String? _resolveValueBindingName({
  required String? bindTo,
  required String? bindValueTo,
}) {
  if (bindTo != null && bindValueTo != null) {
    throw ArgumentError('Specify either bindTo or bindValueTo, not both');
  }

  return bindValueTo ?? bindTo;
}

Map<String, dynamic> _mergeBindingMaps(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final result = <String, dynamic>{...first};

  for (final MapEntry(key: key, value: value) in second.entries) {
    if (result.containsKey(key)) {
      throw StateError('Duplicate model change binding key: $key');
    }

    result[key] = value;
  }

  return result;
}

Map<String, dynamic> _operationValueBindings({
  required FieldOperation operation,
  required String? bindValueTo,
  required String? bindOldValueTo,
  required String? bindNewValueTo,
}) {
  final result = <String, dynamic>{};

  if (bindValueTo != null) {
    result[bindValueTo] = _changedValueForOperation(operation);
  }

  if (bindOldValueTo != null && operation.hasOldValue) {
    result[bindOldValueTo] = operation.oldValue;
  }

  if (bindNewValueTo != null && operation.hasNewValue) {
    result[bindNewValueTo] = operation.newValue;
  }

  return result;
}

/// A node that matches if any of its children match.
///
/// See the documentation on [ModelFilterNode] for context
class ModelFilterOrNode extends ModelFilterNode {
  final List<ModelFilterNode> children;

  ModelFilterOrNode(this.children);

  @override
  void chain(ModelFilterNode next) {
    children.add(next);
  }

  @override
  void replaceNext(ModelFilterNode next) {
    throw UnimplementedError('Or nodes cannot have their next replaced');
  }

  @override
  void allowDescendants() {
    for (final child in children) {
      child.allowDescendants();
    }
  }

  @override
  ModelFilterMatch match(
    Iterable<FieldAccessor> accessors,
    FieldOperation operation,
  ) {
    for (final child in children) {
      final match = child.match(accessors, operation);

      if (match.matches) {
        return match;
      }
    }

    return _noModelFilterMatch;
  }
}

/// A node that matches the current location without consuming an accessor.
class ModelFilterSelfNode extends ModelFilterNode {
  bool includeDescendants = false;
  ModelFilterNode? next;

  @override
  void chain(ModelFilterNode next) {
    if (this.next != null) {
      throw StateError('This node already has a next node');
    }
    this.next = next;
  }

  @override
  void replaceNext(ModelFilterNode next) {
    if (this.next == null) {
      throw StateError('This node does not have a next node');
    }
    this.next = next;
  }

  @override
  void allowDescendants() {
    if (next == null) {
      includeDescendants = true;
      return;
    }

    next!.allowDescendants();
  }

  @override
  ModelFilterMatch match(
    Iterable<FieldAccessor> accessors,
    FieldOperation operation,
  ) {
    if (next != null) {
      return next!.match(accessors, operation);
    }

    if (accessors.isEmpty || includeDescendants) {
      return (matches: true, bindings: const <String, dynamic>{});
    }

    return _noModelFilterMatch;
  }
}

/// A node that matches if the operation at the current level matches the
/// specified field name.
///
/// [next] is another [ModelFilterNode] that represents the next level
/// of the tree, and the next level to match. As an example, if the model looks
/// like this:
///
/// ```dart
/// class A {
///   B b;
/// }
/// class B {
///   C c;
/// }
/// class C {
///   D d;
/// }
/// class D {
///   String field;
/// }
/// ```
///
/// Then a filter that starts at `A` and matches changes to `field` would look
/// like this:
///
/// ```dart
/// ModelFilterFieldNode( // At level A
///   fieldName: 'b',
///   next: ModelFilterFieldNode( // At level B
///     fieldName: 'c',
///     next: ModelFilterFieldNode( // At level C
///       fieldName: 'd',
///       next: ModelFilterFieldNode( // At level D
///         fieldName: 'field',
///         next: null,
///       ),
///     ),
///   ),
/// );
/// ```
class ModelFilterFieldNode extends ModelFilterNode {
  final String fieldName;
  final String? bindValueTo;
  final String? bindOldValueTo;
  final String? bindNewValueTo;
  bool includeDescendants = false;
  ModelFilterNode? next;

  ModelFilterFieldNode({
    required this.fieldName,
    String? bindTo,
    String? bindValueTo,
    this.bindOldValueTo,
    this.bindNewValueTo,
  }) : bindValueTo = _resolveValueBindingName(
         bindTo: bindTo,
         bindValueTo: bindValueTo,
       );

  @override
  void chain(ModelFilterNode next) {
    if (this.next != null) {
      throw StateError('This node already has a next node');
    }
    this.next = next;
  }

  @override
  void replaceNext(ModelFilterNode next) {
    if (this.next == null) {
      throw StateError('This node does not have a next node');
    }
    this.next = next;
  }

  @override
  void allowDescendants() {
    if (next == null) {
      includeDescendants = true;
      return;
    }

    next!.allowDescendants();
  }

  @override
  ModelFilterMatch match(
    Iterable<FieldAccessor> accessors,
    FieldOperation operation,
  ) {
    if (accessors.isEmpty) {
      return _noModelFilterMatch;
    }

    // Check whether the field name matches
    final accessor = accessors.first;
    if (accessor.fieldType != FieldType.raw ||
        accessor.fieldName != fieldName) {
      return _noModelFilterMatch;
    }

    final remainingAccessors = accessors.skip(1);

    final exactMatch = remainingAccessors.isEmpty;
    final descendantMatch = includeDescendants && remainingAccessors.isNotEmpty;

    if (next == null && (exactMatch || descendantMatch)) {
      // If there's no next node, then this is a leaf node and we match
      return (
        matches: true,
        bindings: exactMatch
            ? _operationValueBindings(
                operation: operation,
                bindValueTo: bindValueTo,
                bindOldValueTo: bindOldValueTo,
                bindNewValueTo: bindNewValueTo,
              )
            : const <String, dynamic>{},
      );
    } else if (next == null) {
      // If there's no next node but there are still accessors left, then the
      // change is for a sub-level but this filter is for this level, and so we
      // don't match.
      return _noModelFilterMatch;
    }

    // Otherwise, we need to match the next node with the remaining accessors
    return next!.match(remainingAccessors, operation);
  }
}

/// A node that matches all at the current level.
class ModelFilterWildcardNode extends ModelFilterNode {
  final FieldType? fieldType;
  final String? bindIndexTo;
  final String? bindKeyTo;
  final String? bindValueTo;
  final String? bindOldValueTo;
  final String? bindNewValueTo;
  bool includeDescendants = false;
  ModelFilterNode? next;

  ModelFilterWildcardNode({
    this.fieldType,
    this.bindIndexTo,
    this.bindKeyTo,
    String? bindTo,
    String? bindValueTo,
    this.bindOldValueTo,
    this.bindNewValueTo,
  }) : bindValueTo = _resolveValueBindingName(
         bindTo: bindTo,
         bindValueTo: bindValueTo,
       );

  @override
  void chain(ModelFilterNode next) {
    if (this.next != null) {
      throw StateError('This node already has a next node');
    }
    this.next = next;
  }

  @override
  void replaceNext(ModelFilterNode next) {
    if (this.next == null) {
      throw StateError('This node does not have a next node');
    }
    this.next = next;
  }

  @override
  void allowDescendants() {
    if (next == null) {
      includeDescendants = true;
      return;
    }

    next!.allowDescendants();
  }

  @override
  ModelFilterMatch match(
    Iterable<FieldAccessor> accessors,
    FieldOperation operation,
  ) {
    if (accessors.isEmpty) {
      return _noModelFilterMatch;
    }

    final accessor = accessors.first;
    if (fieldType != null && accessor.fieldType != fieldType) {
      return _noModelFilterMatch;
    }

    final localBindings = <String, dynamic>{};

    if (bindIndexTo != null && accessor.index != null) {
      localBindings[bindIndexTo!] = accessor.index;
    }

    if (bindKeyTo != null && accessor.key != null) {
      localBindings[bindKeyTo!] = accessor.key;
    }

    final remainingAccessors = accessors.skip(1);

    final exactMatch = remainingAccessors.isEmpty;
    final descendantMatch = includeDescendants && remainingAccessors.isNotEmpty;

    if (next == null && (exactMatch || descendantMatch)) {
      // If there's no next node, then this is a leaf node and we match
      return (
        matches: true,
        bindings: _mergeBindingMaps(
          localBindings,
          exactMatch
              ? _operationValueBindings(
                  operation: operation,
                  bindValueTo: bindValueTo,
                  bindOldValueTo: bindOldValueTo,
                  bindNewValueTo: bindNewValueTo,
                )
              : const <String, dynamic>{},
        ),
      );
    } else if (next == null) {
      // If there's no next node but there are still accessors left, then the
      // change is for a sub-level but this filter is for this level, and so we
      // don't match.
      return _noModelFilterMatch;
    }

    // Otherwise, we need to match the next node with the remaining accessors
    final childMatch = next!.match(remainingAccessors, operation);

    if (!childMatch.matches) {
      return _noModelFilterMatch;
    }

    return (
      matches: true,
      bindings: _mergeBindingMaps(localBindings, childMatch.bindings),
    );
  }
}

/// A node that wraps an existing node at the same level to modify it, and
/// matches if the operation type matches one of the specified types.
class ModelFilterChangeTypeModifierNode extends ModelFilterNode {
  final List<ModelFilterChangeType> types;
  ModelFilterNode child;

  ModelFilterChangeTypeModifierNode({required this.types, required this.child});

  @override
  void chain(ModelFilterNode next) {
    child.chain(next);
  }

  @override
  void replaceNext(ModelFilterNode next) {
    child.replaceNext(next);
  }

  @override
  void allowDescendants() {
    child.allowDescendants();
  }

  @override
  ModelFilterMatch match(
    Iterable<FieldAccessor> accessors,
    FieldOperation operation,
  ) {
    final operationType = switch (operation) {
      RawFieldUpdate() => ModelFilterChangeType.fieldUpdate,
      ListInsert() => ModelFilterChangeType.listInsert,
      ListRemove() => ModelFilterChangeType.listRemove,
      ListUpdate() => ModelFilterChangeType.listUpdate,
      MapPut() => ModelFilterChangeType.mapPut,
      MapRemove() => ModelFilterChangeType.mapRemove,
    };

    if (!types.contains(operationType)) {
      return _noModelFilterMatch;
    }

    return child.match(accessors, operation);
  }
}

/// Provides context for [GenericModelFilterBuilder]s to build a filter tree.
class ModelFilterBuilderContext {
  ModelFilterNode? root;
  ModelFilterNode? previous;
  ModelFilterNode? current;

  void addNode(ModelFilterNode node) {
    if (root == null) {
      root = node;
      current = node;
    } else {
      previous = current;
      current?.chain(node);
      current = node;
    }
  }

  void replaceCurrent(ModelFilterNode node) {
    if (current == null) {
      throw StateError('No current node to replace');
    }
    if (previous == null) {
      // We're replacing the root node
      root = node;
    } else {
      previous!.replaceNext(node);
    }
    current = node;
  }

  ModelFilterNode ensureCurrent() {
    if (current == null) {
      addNode(ModelFilterSelfNode());
    }

    return current!;
  }
}

/// Base class for builders that build model filter trees.
///
/// Builders are used to construct filter trees that are used to filter model
/// change streams. They provide a fluent API for building the tree. The
/// builders are exposed to model consumers via the generated onChange method in
/// each model class.
///
/// Example usage:
///
/// ```dart
/// myModel.onChange((b) => b.mySubModel().myField(), (event, bindings) {
///   // Handle change
/// });
/// ```
///
/// In this example, if `myModel` is an instance of `MyModel`, then:
/// - `b` is a generated ModelFilterBuilder for `MyModel`
/// - `b.mySubModel()` returns a generated ModelFilterBuilder for `MySubModel`
/// - `b.mySubModel().myField()` adds the `myField` segment to the filter tree
///   and returns a generic builder for filter modifiers.
class GenericModelFilterBuilder {
  final ModelFilterBuilderContext context;

  GenericModelFilterBuilder filterByChangeType(
    List<ModelFilterChangeType> types,
  ) {
    context.replaceCurrent(
      ModelFilterChangeTypeModifierNode(
        types: types,
        child: context.ensureCurrent(),
      ),
    );
    return this;
  }

  GenericModelFilterBuilder get withDescendants {
    context.ensureCurrent().allowDescendants();
    return this;
  }

  GenericModelFilterBuilder(this.context);
}

/// A builder for list fields.
class ListModelFilterBuilder<T> extends GenericModelFilterBuilder {
  final T Function(ModelFilterBuilderContext context) tGenerator;

  ListModelFilterBuilder({
    required ModelFilterBuilderContext context,
    required this.tGenerator,
  }) : super(context);

  T anyElement({
    String? bindIndexTo,
    String? bindTo,
    String? bindValueTo,
    String? bindOldValueTo,
    String? bindNewValueTo,
  }) {
    context.addNode(
      ModelFilterWildcardNode(
        fieldType: FieldType.list,
        bindIndexTo: bindIndexTo,
        bindTo: bindTo,
        bindValueTo: bindValueTo,
        bindOldValueTo: bindOldValueTo,
        bindNewValueTo: bindNewValueTo,
      ),
    );
    return tGenerator(context);
  }
}

/// A builder for map fields.
class MapModelFilterBuilder<V> extends GenericModelFilterBuilder {
  final V Function(ModelFilterBuilderContext context) valueGenerator;

  MapModelFilterBuilder({
    required ModelFilterBuilderContext context,
    required this.valueGenerator,
  }) : super(context);

  V anyValue({
    String? bindKeyTo,
    String? bindTo,
    String? bindValueTo,
    String? bindOldValueTo,
    String? bindNewValueTo,
  }) {
    context.addNode(
      ModelFilterWildcardNode(
        fieldType: FieldType.map,
        bindKeyTo: bindKeyTo,
        bindTo: bindTo,
        bindValueTo: bindValueTo,
        bindOldValueTo: bindOldValueTo,
        bindNewValueTo: bindNewValueTo,
      ),
    );
    return valueGenerator(context);
  }
}

/// Describes the types of changes that can occur.
enum ModelFilterChangeType {
  fieldUpdate,
  listInsert,
  listRemove,
  listUpdate,
  mapPut,
  mapRemove,
}

/// A listener on an Anthem model, created with [onChange].
///
/// This listener contains a filter to be applied to incoming changes
class ModelFilterListener {
  ModelFilterNode filter;
  void Function(ModelChangeEvent event, ModelChangeBindings bindings) handler;

  ModelFilterListener({required this.filter, required this.handler});
}

typedef ModelFilterEvent = ModelChangeEvent;

class ModelFilterSubscription {
  final void Function() cancel;

  ModelFilterSubscription({required this.cancel});
}
