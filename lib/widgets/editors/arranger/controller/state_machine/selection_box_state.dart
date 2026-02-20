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

part of 'arranger_state_machine.dart';

class ArrangerSelectionBoxState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  ArrangerStateMachine get arrangerStateMachine =>
      stateMachine as ArrangerStateMachine;

  ArrangerStateMachineData get interactionState => arrangerStateMachine.data;

  ArrangerViewModel get viewModel => arrangerStateMachine.viewModel;

  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  Set<Id>? _originalSelectedClipsAtEntry;
  bool _isSubtractiveSelectionLatched = false;

  @visibleForTesting
  Set<Id>? get originalSelectedClipsAtEntry => _originalSelectedClipsAtEntry;

  @visibleForTesting
  bool get isSubtractiveSelectionLatched => _isSubtractiveSelectionLatched;

  Rectangle<double>? _getSelectionBoxRect() {
    final startPosition = parentState.dragStartPosition;
    final currentPosition = parentState.dragCurrentPosition;
    if (startPosition == null || currentPosition == null) {
      return null;
    }

    return Rectangle.fromPoints(
      Point(startPosition.x, startPosition.y),
      Point(currentPosition.x, currentPosition.y),
    );
  }

  void _syncSelectionBox() {
    viewModel.selectionBox = _getSelectionBoxRect();
  }

  Id? _getClipAtDragStart() {
    final startPosition = parentState.dragStartPosition;
    if (startPosition == null) {
      return null;
    }

    final contentUnderCursor = viewModel.getContentUnderCursor(
      Offset(startPosition.x, startPosition.y),
    );

    return contentUnderCursor.clip?.metadata ??
        contentUnderCursor.resizeHandle?.metadata.id;
  }

  void _initializeSelectionSession() {
    if (!interactionState.isShiftPressed) {
      viewModel.selectedClips.clear();
      _originalSelectedClipsAtEntry = Set<Id>.unmodifiable(const <Id>{});
      _isSubtractiveSelectionLatched = false;
      return;
    }

    _originalSelectedClipsAtEntry = Set<Id>.unmodifiable(
      viewModel.selectedClips.nonObservableInner,
    );

    final clipAtDragStart = _getClipAtDragStart();
    _isSubtractiveSelectionLatched =
        clipAtDragStart != null &&
        _originalSelectedClipsAtEntry!.contains(clipAtDragStart);
  }

  void _clearSelectionSession() {
    _originalSelectedClipsAtEntry = null;
    _isSubtractiveSelectionLatched = false;
  }

  Set<Id> _getClipsInSelectionBox({required Rectangle<double> selectionBox}) {
    if (selectionBox.width <= 0 || selectionBox.height <= 0) {
      return {};
    }

    final selectionRect = Rect.fromLTWH(
      selectionBox.left,
      selectionBox.top,
      selectionBox.width,
      selectionBox.height,
    );

    final clipsInSelection = <Id>{};
    for (final annotation in viewModel.visibleClips.getAnnotations()) {
      if (selectionRect.overlaps(annotation.rect)) {
        clipsInSelection.add(annotation.metadata);
      }
    }

    return clipsInSelection;
  }

  void _syncSelectedClips() {
    final originalSelectedClips = _originalSelectedClipsAtEntry;
    final selectionBox = viewModel.selectionBox;
    if (originalSelectedClips == null || selectionBox == null) {
      return;
    }

    final clipsInSelection = _getClipsInSelectionBox(
      selectionBox: selectionBox,
    );
    final nextSelection = _isSubtractiveSelectionLatched
        ? originalSelectedClips.difference(clipsInSelection)
        : originalSelectedClips.union(clipsInSelection);

    viewModel.selectedClips
      ..clear()
      ..addAll(nextSelection);
  }

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate drag to selection box',
      from: ArrangerDragState,
      to: ArrangerSelectionBoxState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as ArrangerDragState).shouldDelegateToSelectionBox,
    ),
    .new(
      name: 'Cancel selection box',
      from: ArrangerSelectionBoxState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          isArrangerCancelSignal(event),
    ),
    .new(
      name: 'Selection box fallback to drag',
      from: ArrangerSelectionBoxState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          !(currentState as ArrangerSelectionBoxState)
              .parentState
              .isDragPointerActive,
    ),
  ];

  ArrangerSelectionBoxState(super.parentState);

  @override
  void onEntry({required event, required from}) {
    viewModel.hoverIndicatorPosition = null;
    _initializeSelectionSession();
    _syncSelectionBox();
    _syncSelectedClips();
  }

  @override
  void onActive({required event}) {
    _syncSelectionBox();
    _syncSelectedClips();
  }

  @override
  void onExit({required event, required to}) {
    final originalSelectedClips = _originalSelectedClipsAtEntry;
    if (isArrangerCancelSignal(event) && originalSelectedClips != null) {
      viewModel.selectedClips
        ..clear()
        ..addAll(originalSelectedClips);
    }

    viewModel.selectionBox = null;
    _clearSelectionSession();
  }
}
