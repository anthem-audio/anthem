/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'dart:math';

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../shared/scroll_manager.dart';
import 'controller/piano_roll_controller.dart';

class PianoRollEventListener extends StatefulWidget {
  final Widget child;
  final Size viewSize;
  final double renderedTimeViewStart;
  final double renderedTimeViewEnd;
  final double renderedKeyHeight;
  final double renderedKeyValueAtTop;

  const PianoRollEventListener({
    super.key,
    required this.child,
    required this.viewSize,
    required this.renderedTimeViewStart,
    required this.renderedTimeViewEnd,
    required this.renderedKeyHeight,
    required this.renderedKeyValueAtTop,
  });

  @override
  State<PianoRollEventListener> createState() => _PianoRollEventListenerState();
}

class _PianoRollEventListenerState extends State<PianoRollEventListener> {
  KeyboardModifiers? _keyboardModifiers;
  PianoRollController? _controller;
  bool _ctrlPressed = false;
  bool _altPressed = false;
  bool _shiftPressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextKeyboardModifiers = Provider.of<KeyboardModifiers>(
      context,
      listen: false,
    );
    if (!identical(_keyboardModifiers, nextKeyboardModifiers)) {
      _keyboardModifiers?.removeListener(_handleKeyboardModifiersChanged);
      _keyboardModifiers = nextKeyboardModifiers
        ..addListener(_handleKeyboardModifiersChanged);
    }

    final nextController = Provider.of<PianoRollController>(
      context,
      listen: false,
    );
    final didControllerChange = !identical(_controller, nextController);
    _controller = nextController;

    if (didControllerChange) {
      _ctrlPressed = false;
      _altPressed = false;
      _shiftPressed = false;
    }

    _handleKeyboardModifiersChanged();
  }

  @override
  void dispose() {
    _keyboardModifiers?.removeListener(_handleKeyboardModifiersChanged);
    super.dispose();
  }

  void _syncModifier({
    required PianoRollModifierKey modifier,
    required bool isPressed,
    required bool wasPressed,
  }) {
    final controller = _controller;
    if (controller == null || isPressed == wasPressed) {
      return;
    }

    if (isPressed) {
      controller.modifierPressed(modifier);
    } else {
      controller.modifierReleased(modifier);
    }
  }

  void _handleKeyboardModifiersChanged() {
    final keyboardModifiers = _keyboardModifiers;
    if (keyboardModifiers == null) {
      return;
    }

    _syncModifier(
      modifier: PianoRollModifierKey.ctrl,
      isPressed: keyboardModifiers.ctrl,
      wasPressed: _ctrlPressed,
    );
    _syncModifier(
      modifier: PianoRollModifierKey.alt,
      isPressed: keyboardModifiers.alt,
      wasPressed: _altPressed,
    );
    _syncModifier(
      modifier: PianoRollModifierKey.shift,
      isPressed: keyboardModifiers.shift,
      wasPressed: _shiftPressed,
    );

    _ctrlPressed = keyboardModifiers.ctrl;
    _altPressed = keyboardModifiers.alt;
    _shiftPressed = keyboardModifiers.shift;
  }

  void handlePointerDown(BuildContext context, PointerDownEvent e) {
    if (e.buttons & kMiddleMouseButton == kMiddleMouseButton) {
      return;
    }

    final controller = Provider.of<PianoRollController>(context, listen: false);
    controller.pointerDown(e);
  }

  void handlePointerMove(BuildContext context, PointerMoveEvent e) {
    if (e.buttons & kMiddleMouseButton == kMiddleMouseButton) {
      return;
    }

    final controller = Provider.of<PianoRollController>(context, listen: false);
    controller.pointerMove(e);
  }

  void handlePointerUp(BuildContext context, PointerEvent e) {
    final controller = Provider.of<PianoRollController>(context, listen: false);
    controller.pointerUp(e);
  }

  var _panPointerYStart = double.nan;
  var _panKeyAtTopStart = double.nan;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);
    final controller = Provider.of<PianoRollController>(context);
    controller.onRenderedViewMetricsChanged(
      viewSize: widget.viewSize,
      timeViewStart: widget.renderedTimeViewStart,
      timeViewEnd: widget.renderedTimeViewEnd,
      keyHeight: widget.renderedKeyHeight,
      keyValueAtTop: widget.renderedKeyValueAtTop,
    );
    return LayoutBuilder(
      builder: (context, boxConstraints) {
        return Observer(
          builder: (context) {
            return EditorScrollManager.timeline(
              timeView: viewModel.timeView,
              onVerticalScrollChange: (delta) {
                final keysPerPixel = 1 / viewModel.keyHeight;
                final scrollAmountInKeys = -delta * 0.5 * keysPerPixel;
                final previousKeyValueAtTop = viewModel.keyValueAtTop;
                final nextKeyValueAtTop = clampDouble(
                  previousKeyValueAtTop + scrollAmountInKeys,
                  minKeyValue +
                      (boxConstraints.maxHeight / viewModel.keyHeight),
                  maxKeyValue,
                );

                viewModel.keyValueAtTop = nextKeyValueAtTop;

                final appliedScrollAmountInKeys =
                    nextKeyValueAtTop - previousKeyValueAtTop;
                if (keysPerPixel == 0) {
                  return 0;
                }

                return -appliedScrollAmountInKeys / (0.5 * keysPerPixel);
              },
              onVerticalPanStart: (y) {
                _panPointerYStart = y;
                _panKeyAtTopStart = viewModel.keyValueAtTop;
              },
              onVerticalPanMove: (y) {
                final deltaY = y - _panPointerYStart;
                final deltaKeySincePanInit = (deltaY / viewModel.keyHeight);

                viewModel.keyValueAtTop =
                    (_panKeyAtTopStart + deltaKeySincePanInit)
                        .clamp(
                          minKeyValue +
                              (boxConstraints.maxHeight / viewModel.keyHeight),
                          maxKeyValue,
                        )
                        .toDouble();
              },
              onVerticalZoom: (pointerY, delta) {
                final viewHeight = boxConstraints.maxHeight;

                // Current state
                final oldKeyHeight = viewModel.keyHeight;
                final oldTop = viewModel.keyValueAtTop;

                // Key under the pointer before zoom
                final keyAtPointerBefore = oldTop - (pointerY / oldKeyHeight);

                // Compute new key height
                final keyHeightLog = log(oldKeyHeight);
                final newKeyHeight = exp(keyHeightLog + delta * 0.4);

                // Apply clamped key height
                viewModel.keyHeight = clampDouble(
                  newKeyHeight,
                  minKeyHeight,
                  maxKeyHeight,
                );

                final h = viewModel.keyHeight;
                if (h == oldKeyHeight) return;

                // Compute the new top so that the same key stays under the pointer
                final newTopUnclamped = keyAtPointerBefore + (pointerY / h);

                // Clamp top so the bottom doesn't go past min and the top past max
                final minTop = minKeyValue + (viewHeight / h);
                final maxTop = maxKeyValue;

                viewModel.keyValueAtTop = clampDouble(
                  newTopUnclamped,
                  minTop,
                  maxTop,
                );
                viewModel.keyValueAtTopAnimationShouldSnap = true;
              },
              child: Listener(
                onPointerDown: (e) {
                  handlePointerDown(context, e);
                },
                onPointerMove: (e) {
                  handlePointerMove(context, e);
                },
                onPointerUp: (e) {
                  handlePointerUp(context, e);
                },

                // If a middle-click or right-click drag goes out of the window, Flutter
                // will temporarily stop receiving move events. If the button is released
                // while the pointer is outside the window in one of these cases, Flutter
                // will call onPointerCancel instead of onPointerUp.
                //
                // We send this to the controller as a pointer up event. If
                // onPointerCancel is called, we will not receive a pointer up event. An
                // event cycle must always contain down, then zero or more moves, then
                // up, and always in that order. We must always finalize the drag and
                // create any necessary undo steps for whatever action has been
                // performed, and we must always do this before starting another drag.
                onPointerCancel: (e) {
                  handlePointerUp(context, e);
                },
                child: widget.child,
              ),
            );
          },
        );
      },
    );
  }
}
