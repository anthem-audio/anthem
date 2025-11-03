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

import 'package:anthem_codegen/include.dart';

/// This class and its subclasses are used to build filters for model change
/// streams.
///
/// The filter is represented as a tree of [ModelFilterTreeBaseNode]s. This tree can
/// be matched against a given model change to either include or exclude it from
/// the stream.
///
/// A tree is built using a [GenericModelFilterBuilder], which is surfaced to model
/// consumers via the generated onChange method in each model class.
sealed class ModelFilterTreeBaseNode {
  /// Generically chains [next] to follow this node in the tree, as the matcher
  /// for the next level down.
  ///
  /// For nodes that can have multiple children (e.g. [ModelFilterOrNode]), this
  /// may be called multiple times to add multiple children.
  void chain(ModelFilterTreeBaseNode next);

  /// Replaces the next node in the chain with [next].
  ///
  /// This is used to wrap existing nodes with modifier nodes, such as
  /// [ModelFilterChangeTypeModifierNode].
  void replaceNext(ModelFilterTreeBaseNode next);

  /// Matches this node and its children against a given change path.
  bool matches(Iterable<FieldAccessor> accessors, FieldOperation operation);
}

/// A node that matches if any of its children match.
///
/// See the documentation on [ModelFilterTreeBaseNode] for context
class ModelFilterOrNode extends ModelFilterTreeBaseNode {
  final List<ModelFilterTreeBaseNode> children;

  ModelFilterOrNode(this.children);

  @override
  void chain(ModelFilterTreeBaseNode next) {
    children.add(next);
  }

  @override
  void replaceNext(ModelFilterTreeBaseNode next) {
    throw UnimplementedError('Or nodes cannot have their next replaced');
  }

  @override
  bool matches(Iterable<FieldAccessor> accessors, FieldOperation operation) {
    if (accessors.isEmpty) {
      return false;
    }

    return children.any((child) => child.matches(accessors, operation));
  }
}

/// A node that matches if the operation at the current level matches the
/// specified field name.
///
/// [next] is another [ModelFilterTreeBaseNode] that represents the next level
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
class ModelFilterFieldNode extends ModelFilterTreeBaseNode {
  final String fieldName;
  ModelFilterTreeBaseNode? next;

  ModelFilterFieldNode({required this.fieldName});

  @override
  void chain(ModelFilterTreeBaseNode next) {
    if (this.next != null) {
      throw StateError('This node already has a next node');
    }
    this.next = next;
  }

  @override
  void replaceNext(ModelFilterTreeBaseNode next) {
    if (this.next == null) {
      throw StateError('This node does not have a next node');
    }
    this.next = next;
  }

  @override
  bool matches(Iterable<FieldAccessor> accessors, FieldOperation operation) {
    if (accessors.isEmpty) {
      return false;
    }

    // Check whether the field name matches
    final accessor = accessors.first;
    if (accessor.fieldName != fieldName) {
      return false;
    }

    if (next == null && accessors.skip(1).isEmpty) {
      // If there's no next node, then this is a leaf node and we match
      return true;
    } else if (next == null) {
      // If there's no next node but there are still accessors left, then the
      // change is for a sub-level but this filter is for this level, and so we
      // don't match.
      return false;
    }

    // Otherwise, we need to match the next node with the remaining accessors
    return next!.matches(accessors.skip(1), operation);
  }
}

/// A node that matches all at the current level.
class ModelFilterPassthroughNode extends ModelFilterTreeBaseNode {
  ModelFilterTreeBaseNode? next;

  ModelFilterPassthroughNode();

  @override
  void chain(ModelFilterTreeBaseNode next) {
    if (this.next != null) {
      throw StateError('This node already has a next node');
    }
    this.next = next;
  }

  @override
  void replaceNext(ModelFilterTreeBaseNode next) {
    if (this.next == null) {
      throw StateError('This node does not have a next node');
    }
    this.next = next;
  }

  @override
  bool matches(Iterable<FieldAccessor> accessors, FieldOperation operation) {
    if (accessors.isEmpty) {
      return false;
    }

    if (next == null && accessors.skip(1).isEmpty) {
      // If there's no next node, then this is a leaf node and we match
      return true;
    } else if (next == null) {
      // If there's no next node but there are still accessors left, then the
      // change is for a sub-level but this filter is for this level, and so we
      // don't match.
      return false;
    }

    // Otherwise, we need to match the next node with the remaining accessors
    return next!.matches(accessors.skip(1), operation);
  }
}

/// A node that wraps an existing node at the same level to modify it, and
/// matches if the operation type matches one of the specified types.
class ModelFilterChangeTypeModifierNode extends ModelFilterTreeBaseNode {
  final List<ModelFilterChangeType> types;
  ModelFilterTreeBaseNode child;

  ModelFilterChangeTypeModifierNode({required this.types, required this.child});

  @override
  void chain(ModelFilterTreeBaseNode next) {
    child.chain(next);
  }

  @override
  void replaceNext(ModelFilterTreeBaseNode next) {
    child.replaceNext(next);
  }

  @override
  bool matches(Iterable<FieldAccessor> accessors, FieldOperation operation) {
    final operationType = switch (operation) {
      RawFieldUpdate() => ModelFilterChangeType.fieldUpdate,
      ListInsert() => ModelFilterChangeType.listInsert,
      ListRemove() => ModelFilterChangeType.listRemove,
      ListUpdate() => ModelFilterChangeType.listUpdate,
      MapPut() => ModelFilterChangeType.mapPut,
      MapRemove() => ModelFilterChangeType.mapRemove,
    };

    if (!types.contains(operationType)) {
      return false;
    }

    return child.matches(accessors, operation);
  }
}

class ModelFilterAllowDescendantsModifierNode extends ModelFilterTreeBaseNode {
  ModelFilterTreeBaseNode child;

  ModelFilterAllowDescendantsModifierNode({required this.child});

  @override
  void chain(ModelFilterTreeBaseNode next) {
    child.chain(next);
  }

  @override
  void replaceNext(ModelFilterTreeBaseNode next) {
    child.replaceNext(next);
  }

  @override
  bool matches(Iterable<FieldAccessor> accessors, FieldOperation operation) {
    // We only give the first accessor to the child, which makes it think that
    // the incoming change is for the current level. This means that if the
    // child would have thrown away the change because it was for a sub-level,
    // it will now match it.
    return child.matches(accessors.take(1), operation);
  }
}

/// Provides context for [GenericModelFilterBuilder]s to build a filter tree.
class ModelFilterBuilderContext {
  ModelFilterTreeBaseNode? root;
  ModelFilterTreeBaseNode? previous;
  ModelFilterTreeBaseNode? current;

  void addNode(ModelFilterTreeBaseNode node) {
    if (root == null) {
      root = node;
      current = node;
    } else {
      previous = current;
      current?.chain(node);
      current = node;
    }
  }

  void replaceCurrent(ModelFilterTreeBaseNode node) {
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
/// myModel.onChange((b) => b.mySubModel.myField, (oldValue, newValue) {
///   // Handle change
/// });
/// ```
///
/// In this example, if `myModel` is an instance of `MyModel`, then:
/// - `b` is a generated ModelFilterBuilder for `MyModel`
/// - `b.mySubModel` returns a generated ModelFilterBuilder for `MySubModel`
/// - `b.mySubModel.myField` returns a builder for the type of `myField`, if one
///    exists - otherwise, it returns `void`, but still modifies the filter tree
///    to match changes to `myField`.
class GenericModelFilterBuilder {
  final ModelFilterBuilderContext context;

  GenericModelFilterBuilder filterByChangeType(
    List<ModelFilterChangeType> types,
  ) {
    context.replaceCurrent(
      ModelFilterChangeTypeModifierNode(types: types, child: context.current!),
    );
    return this;
  }

  GenericModelFilterBuilder get withDescendants {
    context.replaceCurrent(
      ModelFilterAllowDescendantsModifierNode(child: context.current!),
    );
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

  T get anyElement {
    context.addNode(ModelFilterPassthroughNode());
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

  V get anyValue {
    context.addNode(ModelFilterPassthroughNode());
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
  ModelFilterTreeBaseNode filter;
  void Function(ModelFilterEvent event) handler;

  ModelFilterListener({required this.filter, required this.handler});
}

/// An event object that is passed into change handlers.
class ModelFilterEvent {
  List<FieldAccessor> fieldAccessors;
  FieldOperation operation;

  ModelFilterEvent({required this.fieldAccessors, required this.operation});
}

class ModelFilterSubscription {
  final void Function() cancel;

  ModelFilterSubscription({required this.cancel});
}
