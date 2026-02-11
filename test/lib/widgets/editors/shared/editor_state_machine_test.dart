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

import 'dart:async';
import 'dart:math';

import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

class _PointerState {
  bool isDown;
  double x;
  double y;

  _PointerState({required this.isDown, required this.x, required this.y});
}

class _Data {
  bool isCtrlPressed = false;
  final Map<int, _PointerState> pointerMap = <int, _PointerState>{};

  bool get isPointerDown => pointerMap.values.any((pointer) => pointer.isDown);

  void setPointerState({
    required int pointerId,
    required bool isDown,
    required double x,
    required double y,
  }) {
    pointerMap[pointerId] = _PointerState(isDown: isDown, x: x, y: y);
  }

  void removePointer(int pointerId) {
    pointerMap.remove(pointerId);
  }
}

enum _DataHint { pointer }

enum _Signal { cancel }

bool _isCancelSignal(EditorStateMachineEvent event) =>
    event is EditorStateMachineSignalEvent && event.signal == _Signal.cancel;

bool _isDataChangedEvent(EditorStateMachineEvent event) =>
    event is EditorStateMachineDataChangedEvent;

class _IdleState extends EditorStateMachineState<_Data> {}

class _DraggingState extends EditorStateMachineState<_Data> {
  @override
  _IdleState get parentState => super.parentState as _IdleState;

  Point<double> startPos = Point(0, 0);
  Point<double> currentMousePos = Point(0, 0);

  _PointerState? _getTrackedPointer(_Data data) {
    for (final pointer in data.pointerMap.values) {
      if (pointer.isDown) {
        return pointer;
      }
    }
    return data.pointerMap.values.isEmpty ? null : data.pointerMap.values.first;
  }

  bool hasMousePositionChanged(_Data data) {
    final pointer = _getTrackedPointer(data);
    if (pointer == null) {
      return false;
    }
    return currentMousePos.x != pointer.x || currentMousePos.y != pointer.y;
  }

  void updateCurrentMousePosition(_Data data) {
    final pointer = _getTrackedPointer(data);
    if (pointer == null) {
      return;
    }
    currentMousePos = Point(pointer.x, pointer.y);
  }

  @override
  final Iterable<EditorStateMachineStateTransition<_Data>> transitions = [
    .new(
      from: _IdleState,
      to: _DraggingState,
      canTransition: (state, event, currentState) => state.isPointerDown,
    ),
    .new(
      from: _DraggingState,
      to: _IdleState,
      canTransition: (state, event, currentState) => !state.isPointerDown,
    ),
  ];

  @override
  void onEntry({
    required _Data data,
    required EditorStateMachineEvent event,
    required EditorStateMachineState<_Data> from,
  }) {
    if (from is _IdleState) {
      final pointer = _getTrackedPointer(data);
      if (pointer != null) {
        startPos = Point(pointer.x, pointer.y);
      }
    }

    updateCurrentMousePosition(data);
  }

  _DraggingState(_IdleState super.parentState);
}

class _AddNoteState extends EditorStateMachineState<_Data> {
  @override
  _DraggingState get parentState => super.parentState as _DraggingState;

  /// A fake signal for adding a note. In a real scenario, we would mutate
  /// editor state or add an undo/redo command.
  final StreamController<void> noteAddedController =
      StreamController<void>.broadcast();

  /// A fake signal for adding a note. In a real scenario, we would mutate
  /// editor state or add an undo/redo command.
  final StreamController<void> cancelledController =
      StreamController<void>.broadcast();

  @override
  final Iterable<EditorStateMachineStateTransition<_Data>> transitions = [
    // Once we detect a drag, we will add a note if there are no modifiers.
    .new(
      from: _DraggingState,
      to: _AddNoteState,
      canTransition: (data, event, currentState) =>
          _isDataChangedEvent(event) && !data.isCtrlPressed,
    ),

    // Continue handling note creation while pointer moves by re-entering this
    // state when the tracked mouse position changes.
    .new(
      from: _AddNoteState,
      to: _AddNoteState,
      canTransition: (data, event, currentState) =>
          data.isPointerDown &&
          (currentState as _AddNoteState).parentState.hasMousePositionChanged(
            data,
          ),
    ),

    // We go back to the base draggable state when the pointer is released,
    // which releases to idle.
    .new(
      from: _AddNoteState,
      to: _DraggingState,
      canTransition: (state, event, currentState) =>
          !state.isPointerDown || _isCancelSignal(event),
    ),
  ];

  @override
  void onEntry({
    required _Data data,
    required EditorStateMachineEvent event,
    required EditorStateMachineState<_Data> from,
  }) {
    parentState.updateCurrentMousePosition(data);
  }

  @override
  void onExit({
    required _Data data,
    required EditorStateMachineEvent event,
    required EditorStateMachineState<_Data> to,
  }) {
    if (_isCancelSignal(event)) {
      cancelledController.add(null);
      return;
    }

    if (!data.isPointerDown) {
      noteAddedController.add(null);
    }
  }

  _AddNoteState(_DraggingState super.parentState);
}

class _SelectionBoxState extends EditorStateMachineState<_Data> {
  @override
  _DraggingState get parentState => super.parentState as _DraggingState;

  @override
  final Iterable<EditorStateMachineStateTransition<_Data>> transitions = [
    // Once we detect a drag, we will start a selection box if the ctrl modifier
    // is pressed.
    .new(
      from: _DraggingState,
      to: _SelectionBoxState,
      canTransition: (data, event, currentState) =>
          _isDataChangedEvent(event) && data.isCtrlPressed,
    ),

    // We go back to the base draggable state when the pointer is released, which releases to idle.
    .new(
      from: _SelectionBoxState,
      to: _DraggingState,
      canTransition: (state, event, currentState) => !state.isPointerDown,
    ),
  ];

  _SelectionBoxState(_DraggingState super.parentState);
}

void main() {
  late _Data data;
  late EditorStateMachine<_Data> stateMachine;

  late _IdleState idleState;
  late _DraggingState draggingState;
  late _AddNoteState addNoteState;
  late _SelectionBoxState selectionBoxState;

  setUp(() {
    data = _Data();

    idleState = _IdleState();
    draggingState = _DraggingState(idleState);
    addNoteState = _AddNoteState(draggingState);
    selectionBoxState = _SelectionBoxState(draggingState);

    stateMachine = EditorStateMachine(
      data: data,
      idleState: idleState,
      states: [idleState, draggingState, addNoteState, selectionBoxState],
    );
  });

  tearDown(() async {
    await addNoteState.noteAddedController.close();
    await addNoteState.cancelledController.close();
    stateMachine.dispose();
  });

  test('add note state emits noteAdded on pointer release', () async {
    stateMachine.updateData((data) {
      data.setPointerState(pointerId: 1, isDown: true, x: 10, y: 20);
    }, hints: {_DataHint.pointer});

    expect(stateMachine.currentState, isA<_AddNoteState>());

    final noteAdded = addNoteState.noteAddedController.stream.first;

    stateMachine.updateData((data) {
      data.setPointerState(pointerId: 1, isDown: false, x: 12, y: 24);
    }, hints: {_DataHint.pointer});

    await noteAdded;
    expect(stateMachine.currentState, isA<_IdleState>());
  });

  test('add note state emits cancelled on cancel signal', () async {
    stateMachine.updateData((data) {
      data.setPointerState(pointerId: 1, isDown: true, x: 10, y: 20);
    }, hints: {_DataHint.pointer});

    expect(stateMachine.currentState, isA<_AddNoteState>());

    final cancelled = addNoteState.cancelledController.stream.first;

    stateMachine.emitSignal(_Signal.cancel);

    await cancelled;
    expect(stateMachine.currentState, isA<_DraggingState>());
  });

  test('add note state self-transitions when pointer moves', () {
    stateMachine.updateData((data) {
      data.setPointerState(pointerId: 1, isDown: true, x: 10, y: 20);
    }, hints: {_DataHint.pointer});

    expect(stateMachine.currentState, isA<_AddNoteState>());
    expect(draggingState.currentMousePos, Point(10, 20));

    stateMachine.updateData((data) {
      data.setPointerState(pointerId: 1, isDown: true, x: 15, y: 25);
    }, hints: {_DataHint.pointer});

    expect(stateMachine.currentState, isA<_AddNoteState>());
    expect(draggingState.currentMousePos, Point(15, 25));
  });
}
