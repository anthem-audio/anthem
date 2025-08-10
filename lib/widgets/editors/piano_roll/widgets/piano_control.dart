/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../helpers.dart';

const _whiteKeyColor = Color(0xFFC0C0C0);
const _blackKeyColor = Color(0xFF444444);
const _keyBorderColor = Color(0xFF303030);

class DragInfo {
  double startX;
  double startY;

  DragInfo({required this.startX, required this.startY});
}

typedef ValueSetter<T> = void Function(T value);

class PianoControl extends StatefulWidget {
  const PianoControl({
    super.key,
    required this.keyValueAtTop,
    required this.keyHeight,
    required this.setKeyValueAtTop,
  });

  final double keyValueAtTop;
  final double keyHeight;
  final ValueSetter<double> setKeyValueAtTop;

  @override
  State<PianoControl> createState() => _PianoControlState();
}

class _PianoControlState extends State<PianoControl> {
  double startPixelValue = -1.0;
  double startTopKeyValue = -1.0;
  double startKeyHeightValue = -1.0;

  final GlobalKey _containerKey = GlobalKey();

  int? activeKey;

  void setActiveKey(int key) {
    if (activeKey == key) {
      return;
    }

    final project = Provider.of<ProjectModel>(context, listen: false);
    final activeInstrumentId = project.activeInstrumentID;

    if (activeInstrumentId == null) {
      return;
    }

    clearActiveKey();

    activeKey = key;

    project.generators[activeInstrumentId]?.liveEventManager.noteOn(
      pitch: key,
      velocity: 80,
      pan: 0,
    );
  }

  void clearActiveKey() {
    final project = Provider.of<ProjectModel>(context, listen: false);
    final activeInstrumentId = project.activeInstrumentID;

    if (activeInstrumentId == null) {
      return;
    }

    if (activeKey == null) {
      return;
    }

    project.generators[activeInstrumentId]?.liveEventManager.noteOff(
      pitch: activeKey!,
    );

    activeKey = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: _containerKey,
      builder: (context, constraints) {
        // This code does a hit test, then searches for either a _WhiteKey or
        // _BlackKey widget in the hit test result.
        int? findKeyAtPosition(Offset position) {
          final RenderBox renderBox =
              _containerKey.currentContext?.findRenderObject() as RenderBox;
          final result = BoxHitTestResult();

          if (renderBox.hitTest(result, position: position)) {
            bool found = false;
            int? keyNumber;
            void visit(Element element) {
              if (found) return;

              if (element.widget is! _WhiteKey &&
                  element.widget is! _BlackKey) {
                element.visitChildElements(visit);
                return;
              }

              for (final entry in result.path) {
                if (found) return;
                if (element.renderObject == entry.target) {
                  found = true;
                  if (element.widget is _WhiteKey) {
                    keyNumber = (element.widget as _WhiteKey).keyNumber;
                  } else if (element.widget is _BlackKey) {
                    keyNumber = (element.widget as _BlackKey).keyNumber;
                  }
                }
              }
            }

            context.visitChildElements(visit);

            return keyNumber;
          }
          return null;
        }

        final keysOnScreen = constraints.maxHeight / widget.keyHeight;

        final keyValueAtBottom = (widget.keyValueAtTop - keysOnScreen).floor();

        List<int> whiteNotes = [];
        List<int> blackNotes = [];

        for (
          var i = widget.keyValueAtTop.ceil();
          i >= keyValueAtBottom - 1;
          i--
        ) {
          if (getKeyType(i) == KeyType.white) {
            whiteNotes.add(i);
          } else {
            blackNotes.add(i);
          }
        }

        final notes = whiteNotes + blackNotes;

        final noteWidgets = notes.map((note) {
          final keyType = getKeyType(note);

          Widget child;

          if (keyType == KeyType.white) {
            child = _WhiteKey(keyHeight: widget.keyHeight, keyNumber: note);
          } else {
            child = _BlackKey(keyHeight: widget.keyHeight, keyNumber: note);
          }

          return LayoutId(id: note, child: child);
        }).toList();

        return Listener(
          child: ClipRect(
            child: Container(
              color: _keyBorderColor,
              child: CustomMultiChildLayout(
                delegate: KeyLayoutDelegate(
                  keyHeight: widget.keyHeight,
                  keyValueAtTop: widget.keyValueAtTop,
                  notes: notes,
                  parentHeight: constraints.maxHeight,
                ),
                children: noteWidgets,
              ),
            ),
          ),
          onPointerDown: (e) {
            final key = findKeyAtPosition(e.localPosition);
            if (key != null) {
              setActiveKey(key);
            } else {
              clearActiveKey();
            }
          },
          onPointerMove: (e) {
            final key = findKeyAtPosition(e.localPosition);
            if (key != null) {
              setActiveKey(key);
            } else {
              clearActiveKey();
            }
          },
          onPointerUp: (e) {
            clearActiveKey();
          },
          onPointerCancel: (e) {
            clearActiveKey();
          },
        );
      },
    );
  }
}

class KeyLayoutDelegate extends MultiChildLayoutDelegate {
  KeyLayoutDelegate({
    required this.notes,
    required this.keyHeight,
    required this.keyValueAtTop,
    required this.parentHeight,
  });

  final List<int> notes;
  final double keyValueAtTop;
  final double keyHeight;
  final double parentHeight;

  @override
  void performLayout(Size size) {
    for (var note in notes) {
      final keyType = getKeyType(note);
      final notchType = getNotchType(note);

      var y =
          keyValueToPixels(
            keyValue: note.toDouble(),
            keyValueAtTop: keyValueAtTop,
            keyHeight: keyHeight,
          ) -
          keyHeight +
          1;

      if (keyType == KeyType.white &&
          (notchType == NotchType.above || notchType == NotchType.both)) {
        y -= keyHeight * 0.5;
      }

      layoutChild(note, BoxConstraints(maxWidth: size.width));
      positionChild(note, Offset(0, y));
    }
  }

  @override
  bool shouldRelayout(covariant KeyLayoutDelegate oldDelegate) {
    return oldDelegate.keyHeight != keyHeight ||
        oldDelegate.keyValueAtTop != keyValueAtTop ||
        oldDelegate.parentHeight != parentHeight;
  }
}

const notchWidth = 22.0;

class _WhiteKey extends StatelessWidget {
  const _WhiteKey({required this.keyNumber, required this.keyHeight});

  final int keyNumber;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    final showKeyText = keyHeight > 25 && keyNumber % 12 == 0;

    final notchType = getNotchType(keyNumber);
    final widgetHeight = notchType == NotchType.both
        ? keyHeight * 2
        : keyHeight * 1.5;

    final double opacity = keyNumber < minKeyValue || keyNumber > maxKeyValue
        ? 0.7
        : 1;

    return Container(
      height: widgetHeight - 1,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(1)),
        color: _whiteKeyColor.withValues(alpha: opacity),
      ),
      child: showKeyText
          ? Center(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: 4,
                    // Aligns this text with the text in the notes
                    top: keyHeight * 0.5 + 1,
                  ),
                  child: Text(
                    style: const TextStyle(color: _blackKeyColor),
                    keyToString(keyNumber),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _BlackKey extends StatelessWidget {
  const _BlackKey({required this.keyNumber, required this.keyHeight});

  final int keyNumber;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
        border: Border.all(width: 1, color: _keyBorderColor),
        color: _blackKeyColor,
      ),
      height: keyHeight - 1,
      margin: const EdgeInsets.only(right: notchWidth + 1),
    );
  }
}
