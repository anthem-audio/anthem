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
    currentState = idleState;
    const startEvent = EditorStateMachineStartEvent();
    _evaluateTransitions(startEvent);
  }

  /// Mutates [data] and then evaluates transitions.
  void updateData(
    void Function(TData data) mutator, {
    Set<Object> hints = const <Object>{},
  }) {
    if (_isDisposed) {
      return;
    }

    mutator(data);
    _enqueueEvent(EditorStateMachineDataChangedEvent());
  }

  /// Evaluates transitions without mutating data.
  void invalidate() {
    if (_isDisposed) {
      return;
    }

    _enqueueEvent(EditorStateMachineDataChangedEvent());
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

    while (true) {
      final transition = _findFirstValidTransition(event);
      if (transition == null) {
        return;
      }

      final from = currentState;
      final to = states[transition.to]!;

      currentState.onExit(data: data, event: event, to: to);
      currentState = to;
      currentState.onEntry(data: data, event: event, from: from);

      processedTransitions++;
      if (processedTransitions >= _maxTransitionsPerCycle) {
        throw StateError(
          'Exceeded transition processing limit while handling one data change.',
        );
      }
    }
  }

  EditorStateMachineStateTransition<TData>? _findFirstValidTransition(
    EditorStateMachineEvent event,
  ) {
    for (final transition in transitions) {
      if (transition.from != currentState.runtimeType) {
        continue;
      }

      if (transition.canTransition(data, event, currentState)) {
        return transition;
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
  final EditorStateMachineState<TData>? parentState;

  EditorStateMachineState([this.parentState]);

  void onEntry({
    required TData data,
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TData> from,
  }) {}

  void onExit({
    required TData data,
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TData> to,
  }) {}

  Iterable<EditorStateMachineStateTransition<TData>> get transitions => [];
}

class EditorStateMachineStateTransition<TData> {
  final Type from;
  final Type to;
  final bool Function(
    TData data,
    EditorStateMachineEvent event,
    EditorStateMachineState<TData> currentState,
  )
  canTransition;

  EditorStateMachineStateTransition({
    required this.from,
    required this.to,
    required this.canTransition,
  });
}
