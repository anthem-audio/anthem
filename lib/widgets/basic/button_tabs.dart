/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/helpers/measure_text.dart';
import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

import 'icon.dart';

class ButtonTabs<T> extends StatefulWidget {
  final List<ButtonTabDef<T>> tabs;
  final T? selected;
  final void Function(T id)? onChange;

  const ButtonTabs({
    super.key,
    required this.tabs,
    this.selected,
    this.onChange,
  });

  @override
  State<ButtonTabs<T>> createState() => _ButtonTabsState<T>();
}

class _ButtonTabsState<T> extends State<ButtonTabs<T>> {
  T? selectedFallback;

  @override
  Widget build(BuildContext context) {
    selectedFallback ??= widget.tabs.first.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        final List<Widget> rowChildren = [];
        List<double> tabWidths = [];

        for (final tab in widget.tabs) {
          if (tab.type == ButtonTabType.icon) {
            tabWidths.add(8 + 16 + 8);
          } else {
            const style = TextStyle(fontSize: 11);
            tabWidths.add(
              8 +
                  measureText(
                    text: tab.text!,
                    textStyle: style,
                    context: context,
                  ).width +
                  8,
            );
          }
        }

        var rowWidth = tabWidths.fold<double>(
            0, (previousValue, element) => previousValue + element);

        if (rowWidth < constraints.maxWidth && constraints.maxWidth.isFinite) {
          final correction = constraints.maxWidth - rowWidth;
          tabWidths = tabWidths
              .map((size) => size + correction / tabWidths.length)
              .toList();
          rowWidth += correction;
        }

        for (final tab in widget.tabs) {
          final isSelected = tab.id == (widget.selected ?? selectedFallback);
          final color = isSelected ? Theme.primary.main : Theme.text.main;

          final Widget content;

          if (tab.type == ButtonTabType.icon) {
            content = SvgIcon(icon: tab.icon!, color: color);
            tabWidths.add(8 + 16 + 8);
          } else {
            final style = TextStyle(color: color, fontSize: 11);
            content = Center(child: Text(tab.text!, style: style));
            tabWidths.add(8 +
                measureText(text: tab.text!, textStyle: style, context: context)
                    .width +
                8);
          }

          rowChildren.add(content);
        }

        final selectedItemIndex = widget.tabs.indexWhere(
            (element) => element.id == (widget.selected ?? selectedFallback!));

        // Includes one more item than the number of tabs
        final List<double> tabPixelPositions = [0];
        var accumulator = 0.0;

        for (var i = 0; i < widget.tabs.length; i++) {
          accumulator += tabWidths[i];
          tabPixelPositions.add(accumulator);
        }

        return SizedBox(
          width: rowWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.panel.border),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                    // It would be nice to have this animation, but it triggers
                    // on widget resize, whereas it should only happen on
                    // click. I'm not sure how best to do this and I don't want
                    // to tackle it now.
                    // AnimatedPositioned(
                    //   duration: defaultAnimationDuration,
                    //   curve: defaultAnimationCurve,
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: tabPixelPositions[selectedItemIndex],
                      right:
                          rowWidth - tabPixelPositions[selectedItemIndex + 1],
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.panel.border),
                          borderRadius: BorderRadius.circular(4),
                          color: Theme.panel.accent,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: rowChildren,
                      ),
                    ),
                  ] +
                  List.generate(widget.tabs.length, (index) => index)
                      .map<Widget>((index) {
                    final tab = widget.tabs[index];

                    void onPointerUp(PointerEvent e) {
                      setState(() {
                        selectedFallback = tab.id;
                      });
                      widget.onChange?.call(tab.id);
                    }

                    return Positioned(
                      top: 0,
                      bottom: 0,
                      left: tabPixelPositions[index],
                      right: rowWidth - tabPixelPositions[index + 1],
                      child: Listener(
                        onPointerUp: onPointerUp,
                        onPointerCancel: onPointerUp,
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }
}

enum ButtonTabType { text, icon }

class ButtonTabDef<T> {
  T id;
  String? text;
  IconDef? icon;

  ButtonTabDef.withText({required String this.text, required this.id});
  ButtonTabDef.withIcon({required IconDef this.icon, required this.id});

  ButtonTabType get type {
    if (text != null) {
      return ButtonTabType.text;
    } else if (icon != null) {
      return ButtonTabType.icon;
    } else {
      throw Exception('Malformed ButtonTabDef');
    }
  }
}
