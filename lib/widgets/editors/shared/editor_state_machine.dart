/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:collection';

import 'package:collection/collection.dart';

/// A state machine to manage user interactions with editors.
///
/// This class requires three inputs:
/// - A set of arbitrary data items that represent interaction state.
/// - A set of state machine states.
/// - A set of transitions between those states.
///
/// Then, when data changes are invalidated or signals are emitted, this class
/// evaluates transitions and delegates behavior to active state logic.
///
/// This machine supports hierarchical state behavior via [parentState].
/// Per event, processing runs in this order:
/// 1. [EditorStateMachineState.onActive] for all active states from root to
///    leaf.
/// 2. Transition resolution from leaf to root.
/// 3. Transition callbacks: `onTransition`, then `onExit`, then `onEntry`.
///
/// For hierarchical transitions, exits/entries are applied relative to the
/// first shared ancestor between the current leaf and target leaf:
/// - `onExit` runs from current leaf upward to (but excluding) that ancestor.
/// - `onEntry` runs from the next child below that ancestor down to target
///   leaf.
///
/// This class exists because of the enormous complexity in handling each
/// interaction in complex editors like the ones in this software. In UI code,
/// we typically handle pointer events directly in event handlers, and possibly
/// track some component-level state to aid in handling these events. However,
/// this approach does not work here, because even a simple pointer move event
/// can mean a dozen different things depending on the current state.
///
/// Differentiating between these behaviors is incredibly complicated in a
/// single event handler, and so this class exists to try and separate distinct
/// behaviors while abstracting some of the complexity of state management
/// within this context.
class EditorStateMachine<TData> {
  final TData data;
  final EditorStateMachineState<TData> idleState;
  final Map<Type, EditorStateMachineState<TData>> states;
  final List<EditorStateMachineStateTransition<TData>> transitions;
  late final Map<Type, List<EditorStateMachineState<TData>>>
  _statePathsFromRootByType;

  /// The current active leaf state.
  late EditorStateMachineState<TData> currentState;

  static const int _maxTransitionsPerCycle = 1024;

  final Queue<EditorStateMachineEvent> _pendingEvents =
      Queue<EditorStateMachineEvent>();

  bool _isProcessingEvents = false;
  bool _isDisposed = false;

  EditorStateMachine({
    required this.data,
    required this.idleState,
    required List<EditorStateMachineState<TData>> states,
  }) : states = Map.unmodifiable(
         Map.fromEntries(
           states.map((state) => MapEntry(state.runtimeType, state)),
         ),
       ),
       transitions = List.unmodifiable(
         states.map((s) => s.transitions).flattened,
       ) {
    if (states.length != this.states.length) {
      throw StateError(
        'Only one instance of each EditorStateMachineState subclass is allowed.',
      );
    }

    for (final state in states) {
      state.stateMachine = this;
    }

    _initializeStateHierarchy();

    currentState = idleState;
    const startEvent = EditorStateMachineStartEvent();
    _evaluateTransitions(startEvent);
  }

  /// Notifies the state machine that [data] has already been mutated.
  ///
  /// Call this after making one or more changes to [data] so active states and
  /// transitions are reevaluated.
  void notifyDataUpdated() {
    if (_isDisposed) {
      return;
    }

    _enqueueEvent(const EditorStateMachineDataChangedEvent());
  }

  /// Emits an arbitrary signal (for example `cancel` or `escape`).
  void emitSignal(Object signal) {
    if (_isDisposed) {
      return;
    }

    _enqueueEvent(EditorStateMachineSignalEvent(signal));
  }

  void _enqueueEvent(EditorStateMachineEvent event) {
    _pendingEvents.add(event);
    if (_isProcessingEvents) {
      return;
    }

    _isProcessingEvents = true;
    try {
      while (_pendingEvents.isNotEmpty) {
        _evaluateTransitions(_pendingEvents.removeFirst());
      }
    } finally {
      _isProcessingEvents = false;
    }
  }

  void _evaluateTransitions(EditorStateMachineEvent event) {
    var processedTransitions = 0;

    // Parent states can update shared derived data before child behavior.
    _runActiveStateUpdates(event);

    while (true) {
      final transition = _findFirstValidTransition(event);
      if (transition == null) {
        return;
      }

      _applyTransition(event, transition);

      processedTransitions++;
      if (processedTransitions >= _maxTransitionsPerCycle) {
        throw StateError(
          'Exceeded transition processing limit while handling one data change.',
        );
      }
    }
  }

  void _initializeStateHierarchy() {
    if (!identical(states[idleState.runtimeType], idleState)) {
      throw StateError(
        'The idle state instance must be included in the state list.',
      );
    }

    final paths = <Type, List<EditorStateMachineState<TData>>>{};

    for (final state in states.values) {
      final pathFromLeaf = <EditorStateMachineState<TData>>[];
      final visited = <EditorStateMachineState<TData>>{};

      EditorStateMachineState<TData>? cursor = state;
      while (cursor != null) {
        if (!visited.add(cursor)) {
          throw StateError(
            'Detected a parent state cycle involving ${state.runtimeType}.',
          );
        }

        final registeredState = states[cursor.runtimeType];
        if (!identical(registeredState, cursor)) {
          throw StateError(
            'State ${state.runtimeType} references parent ${cursor.runtimeType}, but that parent instance is not registered in this machine.',
          );
        }

        pathFromLeaf.add(cursor);
        cursor = cursor.parentState;
      }

      final pathFromRoot = pathFromLeaf.reversed.toList(growable: false);
      paths[state.runtimeType] = List.unmodifiable(pathFromRoot);
    }

    _statePathsFromRootByType = Map.unmodifiable(paths);
  }

  List<EditorStateMachineState<TData>> _statePathFromRoot(
    EditorStateMachineState<TData> state,
  ) {
    final path = _statePathsFromRootByType[state.runtimeType];
    if (path == null || !identical(path.last, state)) {
      throw StateError(
        'State ${state.runtimeType} is not registered in this machine.',
      );
    }

    return path;
  }

  void _runActiveStateUpdates(EditorStateMachineEvent event) {
    // Execute from root to leaf so parent state updates are visible to children.
    final activePath = _statePathFromRoot(currentState);
    for (final state in activePath) {
      state.onActive(event: event);
    }
  }

  void _applyTransition(
    EditorStateMachineEvent event,
    _ResolvedTransition<TData> resolvedTransition,
  ) {
    final fromLeaf = currentState;
    final toLeaf = resolvedTransition.targetState;

    resolvedTransition.transition.onTransition?.call(
      event: event,
      from: resolvedTransition.sourceState,
      to: toLeaf,
    );

    if (identical(fromLeaf, toLeaf)) {
      // Preserve self-transition re-entry semantics.
      fromLeaf.onExit(event: event, to: toLeaf);
      currentState = toLeaf;
      toLeaf.onEntry(event: event, from: fromLeaf);
      return;
    }

    final fromPath = _statePathFromRoot(fromLeaf);
    final toPath = _statePathFromRoot(toLeaf);
    final sharedPrefixLength = _sharedPathPrefixLength(fromPath, toPath);

    // Exit leaf -> ancestor (exclusive), then enter ancestor child -> new leaf.
    final statesToExit = fromPath.sublist(sharedPrefixLength).reversed;
    for (final state in statesToExit) {
      state.onExit(event: event, to: toLeaf);
    }

    currentState = toLeaf;

    final statesToEnter = toPath.sublist(sharedPrefixLength);
    for (final state in statesToEnter) {
      state.onEntry(event: event, from: fromLeaf);
    }
  }

  int _sharedPathPrefixLength(
    List<EditorStateMachineState<TData>> a,
    List<EditorStateMachineState<TData>> b,
  ) {
    final minLength = a.length < b.length ? a.length : b.length;
    var index = 0;

    while (index < minLength && identical(a[index], b[index])) {
      index++;
    }

    return index;
  }

  _ResolvedTransition<TData>? _findFirstValidTransition(
    EditorStateMachineEvent event,
  ) {
    final activePath = _statePathFromRoot(currentState);

    // Child states get first chance to transition; parents can still delegate.
    for (final sourceState in activePath.reversed) {
      for (final transition in transitions) {
        if (transition.from != sourceState.runtimeType) {
          continue;
        }

        if (!transition.canTransition(
          data: data,
          event: event,
          currentState: sourceState,
        )) {
          continue;
        }

        final toState = states[transition.to];
        if (toState == null) {
          throw StateError(
            'Transition "${transition.name}" targets ${transition.to}, which is not registered.',
          );
        }

        final isAncestorToAlreadyActivePathTransition =
            !identical(sourceState, currentState) &&
            activePath.any((activeState) => identical(activeState, toState));
        if (isAncestorToAlreadyActivePathTransition &&
            !transition.allowAncestorToActivePathTransition) {
          // Avoid repeated ancestor->already-active transitions each event.
          continue;
        }

        return _ResolvedTransition(
          transition: transition,
          sourceState: sourceState,
          targetState: toState,
        );
      }
    }

    return null;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _pendingEvents.clear();
  }
}

sealed class EditorStateMachineEvent {
  const EditorStateMachineEvent();
}

class EditorStateMachineStartEvent extends EditorStateMachineEvent {
  const EditorStateMachineStartEvent();
}

class EditorStateMachineDataChangedEvent extends EditorStateMachineEvent {
  const EditorStateMachineDataChangedEvent();
}

class EditorStateMachineSignalEvent extends EditorStateMachineEvent {
  final Object signal;

  const EditorStateMachineSignalEvent(this.signal);
}

abstract class EditorStateMachineState<TData> {
  late final EditorStateMachine<TData> stateMachine;
  final EditorStateMachineState<TData>? parentState;

  EditorStateMachineState([this.parentState]);

  /// Called once per processed event while this state is active.
  ///
  /// Active states are updated from root to leaf before transition resolution.
  void onActive({required EditorStateMachineEvent event}) {}

  /// Called when this state is entered as part of a transition.
  ///
  /// For hierarchical transitions, this may be called on multiple states from
  /// the first child below the shared ancestor down to the target leaf.
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TData> from,
  }) {}

  /// Called when this state is exited as part of a transition.
  ///
  /// For hierarchical transitions, this may be called on multiple states from
  /// the current leaf up to the first child below the shared ancestor.
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TData> to,
  }) {}

  Iterable<EditorStateMachineStateTransition<TData>> get transitions => [];
}

class EditorStateMachineStateTransition<TData> {
  final String name;
  final Type from;
  final Type to;
  final bool Function({
    required TData data,
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TData> currentState,
  })
  canTransition;
  final void Function({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TData> from,
    required EditorStateMachineState<TData> to,
  })?
  onTransition;

  /// If `false` (default), ancestor transitions that target any state already
  /// in the active path are skipped to prevent transition churn.
  ///
  /// Set to `true` only when repeated ancestor-driven re-entry is intentional.
  final bool allowAncestorToActivePathTransition;

  EditorStateMachineStateTransition({
    this.name = '',
    required this.from,
    required this.to,
    required this.canTransition,
    this.onTransition,
    this.allowAncestorToActivePathTransition = false,
  });
}

class _ResolvedTransition<TData> {
  final EditorStateMachineStateTransition<TData> transition;
  final EditorStateMachineState<TData> sourceState;
  final EditorStateMachineState<TData> targetState;

  _ResolvedTransition({
    required this.transition,
    required this.sourceState,
    required this.targetState,
  });
}
