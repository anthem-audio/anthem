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

import 'package:anthem/helpers/constants.dart';
import 'package:anthem/helpers/measure_text.dart';
import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

import 'icon.dart';

class ButtonTabs<T> extends StatefulWidget {
  final List<ButtonTabDef<T>> tabs;
  final T? selected;
  final Function(T id)? onChange;

  const ButtonTabs({
    Key? key,
    required this.tabs,
    this.selected,
    this.onChange,
  }) : super(key: key);

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
          final isSelected = tab.id == (widget.selected ?? selectedFallback);
          final color = isSelected ? Theme.primary.main : Theme.text.main;

          final Widget content;

          if (tab.type == _ButtonTabType.icon) {
            content = SvgIcon(icon: tab.icon!, color: color);
            tabWidths.add(8 + 16 + 8);
          } else {
            final style = TextStyle(color: color, fontSize: 11);
            content = Center(child: Text(tab.text!, style: style));
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

          rowChildren.add(Listener(
            onPointerUp: (event) {
              setState(() {
                selectedFallback = tab.id;
              });
              widget.onChange?.call(tab.id);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: content,
              ),
            ),
          ));
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

        final selectedItemIndex = widget.tabs.indexWhere(
            (element) => element.id == (widget.selected ?? selectedFallback!));

        var selectedItemStart = 0.0;
        var selectedItemEnd = tabWidths[0];

        for (var i = 1; i <= selectedItemIndex; i++) {
          selectedItemStart += tabWidths[i - 1];
          selectedItemEnd += tabWidths[i];
        }

        return SizedBox(
          width: rowWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.panel.border),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    return AnimatedPositioned(
                      duration: defaultAnimationDuration,
                      curve: defaultAnimationCurve,
                      top: 0,
                      bottom: 0,
                      left: selectedItemStart,
                      right: rowWidth - selectedItemEnd,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.panel.border),
                          borderRadius: BorderRadius.circular(4),
                          color: Theme.panel.accent,
                        ),
                      ),
                    );
                  }
                ),
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rowChildren,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _ButtonTabType { text, icon }

class ButtonTabDef<T> {
  T id;
  String? text;
  IconDef? icon;

  ButtonTabDef.withText({required String this.text, required this.id});
  ButtonTabDef.withIcon({required IconDef this.icon, required this.id});

  _ButtonTabType get type {
    if (text != null) {
      return _ButtonTabType.text;
    } else if (icon != null) {
      return _ButtonTabType.icon;
    } else {
      throw Exception("Malformed ButtonTabDef");
    }
  }
}
