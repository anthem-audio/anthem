/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:flutter/widgets.dart';

import '../helpers.dart';

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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

        final noteWidgets =
            notes.map((note) {
              final keyType = getKeyType(note);

              Widget child;

              if (keyType == KeyType.white) {
                child = _WhiteKey(keyHeight: widget.keyHeight, keyNumber: note);
              } else {
                child = _BlackKey(keyHeight: widget.keyHeight, keyNumber: note);
              }

              return LayoutId(id: note, child: child);
            }).toList();

        return ClipRect(
          child: CustomMultiChildLayout(
            delegate: KeyLayoutDelegate(
              keyHeight: widget.keyHeight,
              keyValueAtTop: widget.keyValueAtTop,
              notes: notes,
              parentHeight: constraints.maxHeight,
            ),
            children: noteWidgets,
          ),
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
          // this is why I want Dart support for Prettier
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
    final showKeyText = keyHeight > 25 && (keyNumber - 3) % 12 == 0;

    final notchType = getNotchType(keyNumber);
    final widgetHeight =
        notchType == NotchType.both ? keyHeight * 2 : keyHeight * 1.5;

    final double opacity =
        keyNumber < minKeyValue || keyNumber > maxKeyValue ? 0.7 : 1;

    return Container(
      height: widgetHeight - 1,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(1)),
        color: const Color(0xFFAAB7C0).withValues(alpha: opacity),
      ),
      child:
          showKeyText
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
                      style: const TextStyle(color: blackKeyColor),
                      keyToString(keyNumber),
                    ),
                  ),
                ),
              )
              : null,
    );
  }
}

const blackKeyColor = Color(0xFF3D484F);

class _BlackKey extends StatelessWidget {
  const _BlackKey({required this.keyNumber, required this.keyHeight});

  final int keyNumber;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
        color: blackKeyColor,
      ),
      height: keyHeight - 1,
      margin: const EdgeInsets.only(right: notchWidth + 1),
    );
  }
}
