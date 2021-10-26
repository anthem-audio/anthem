/*
  Copyright (C) 2021 Joshua Wade

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

import 'package:flutter/widgets.dart';

import 'helpers.dart';

class DragInfo {
  double startX;
  double startY;

  DragInfo({required this.startX, required this.startY});
}

typedef ValueSetter<T> = void Function(T value);

class PianoControl extends StatefulWidget {
  const PianoControl({
    Key? key,
    required this.keyValueAtTop,
    required this.keyHeight,
    required this.setKeyValueAtTop,
    required this.setKeyHeight,
  }) : super(key: key);

  final double keyValueAtTop;
  final double keyHeight;
  final ValueSetter<double> setKeyValueAtTop;
  final ValueSetter<double> setKeyHeight;

  @override
  State<PianoControl> createState() => _PianoControlState();
}

class _PianoControlState extends State<PianoControl> {
  double startPixelValue =-1.0;
  double startTopKeyValue =-1.0;
  double startKeyHeightValue =-1.0;

  @override
  Widget build(BuildContext context) {
    final contentRenderBox = context.findRenderObject() as RenderBox?;

    return Row(
      children: [
        Listener(
          onPointerDown: (e) {
            startPixelValue = e.localPosition.dy;
            startTopKeyValue = widget.keyValueAtTop;
            startKeyHeightValue = widget.keyHeight;
          },
          onPointerMove: (e) {
            // if (!keyboardModifiers.alt) {
              final keyDelta =
                  (e.localPosition.dy - startPixelValue) / widget.keyHeight;
              widget.setKeyValueAtTop(startTopKeyValue + keyDelta);
            // } else {
            //   widget.setKeyHeight((startKeyHeightValue +
            //           (e.localPosition.dy - startPixelValue) / 3)
            //       .clamp(4, 50));
            // }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(1)),
              color: const Color(0xFFFFFFFF).withOpacity(0.12),
            ),
            width: 39,
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          child: ClipRect(
            child: (() {
              if (contentRenderBox == null) {
                return const SizedBox();
              }

              var keyValueAtBottom =
                  (widget.keyValueAtTop - contentRenderBox.size.height / widget.keyHeight)
                      .floor();

              List<int> notes = [];

              for (var i = widget.keyValueAtTop.ceil(); i >= keyValueAtBottom; i--) {
                notes.add(i);
              }

              var noteWidgets = notes.map((note) {
                var keyType = getKeyType(note);

                Widget child;

                if (keyType == KeyType.white) {
                  child = _WhiteKey(keyHeight: widget.keyHeight, keyNumber: note);
                } else {
                  child = _BlackKey(keyHeight: widget.keyHeight, keyNumber: note);
                }

                return LayoutId(id: note, child: child);
              }).toList();

              return CustomMultiChildLayout(
                delegate: KeyLayoutDelegate(
                  keyHeight: widget.keyHeight,
                  keyValueAtTop: widget.keyValueAtTop,
                  notes: notes,
                  parentHeight: contentRenderBox.size.height,
                ),
                children: noteWidgets,
              );
            })(),
          ),
        ),
      ],
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

      var y = keyValueToPixels(
              keyValue: note.toDouble(),
              keyValueAtTop: keyValueAtTop,
              keyHeight: keyHeight) -
          keyHeight +
          // this is why I want Dart support for Prettier
          1;

      if (keyType == KeyType.white &&
          (notchType == NotchType.above || notchType == NotchType.both)) {
        y -= keyHeight * 0.5;
      }

      layoutChild(
        note,
        BoxConstraints(maxWidth: size.width),
      );
      positionChild(note, Offset(0, y));
    }
  }

  @override
  bool shouldRelayout(covariant KeyLayoutDelegate oldDelegate) {
    if (oldDelegate.keyHeight != keyHeight ||
        oldDelegate.keyValueAtTop != keyValueAtTop ||
        oldDelegate.parentHeight != parentHeight) return true;
    return false;
  }
}

const notchWidth = 22.0;

class _WhiteKey extends StatelessWidget {
  const _WhiteKey({Key? key, required this.keyNumber, required this.keyHeight})
      : super(key: key);

  final int keyNumber;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    final notchType = getNotchType(keyNumber);
    final widgetHeight =
        notchType == NotchType.both ? keyHeight * 2 : keyHeight * 1.5;
    final hasTopNotch =
        notchType == NotchType.both || notchType == NotchType.above;
    final hasBottomNotch =
        notchType == NotchType.both || notchType == NotchType.below;

    // 41 / 22

    // 128 here is arbitrary
    final opacity = keyNumber < 0 || keyNumber > 128 ? 0.3 : 0.6;

    return GestureDetector(
        onTap: () {
          print(keyNumber);
        },
        child: SizedBox(
          height: widgetHeight - 1,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    SizedBox(height: hasTopNotch ? keyHeight * 0.5 : 0),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(1),
                            bottomLeft: Radius.circular(1),
                          ),
                          color: const Color(0xFFFFFFFF).withOpacity(opacity),
                        ),
                      ),
                    ),
                    SizedBox(height: hasBottomNotch ? keyHeight * 0.5 : 0),
                  ],
                ),
              ),
              Container(
                width: notchWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(hasTopNotch ? 1 : 0),
                    bottomLeft: Radius.circular(hasBottomNotch ? 1 : 0),
                    topRight: const Radius.circular(1),
                    bottomRight: const Radius.circular(1),
                  ),
                  color: const Color(0xFFFFFFFF).withOpacity(opacity),
                ),
              ),
            ],
          ),
        ));
  }
}

class _BlackKey extends StatelessWidget {
  const _BlackKey({Key? key, required this.keyNumber, required this.keyHeight})
      : super(key: key);

  final int keyNumber;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(1)),
        color: const Color(0xFFFFFFFF).withOpacity(0.07),
      ),
      height: keyHeight - 1,
      margin: const EdgeInsets.only(right: notchWidth + 1),
    );
  }
}
