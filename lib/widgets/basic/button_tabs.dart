/*
  Copyright (C) 2025 Joshua Wade

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

import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

class ButtonTabProps {
  final bool isHovered;
  final bool isSelected;

  ButtonTabProps({required this.isHovered, required this.isSelected});
}

typedef ButtonTabsBuilder =
    Widget Function(BuildContext context, ButtonTabProps props);

class ButtonTabs extends StatelessWidget {
  final List<ButtonTabsBuilder> builders;
  final int selectedIndex;
  final void Function(int index)? onChange;

  const ButtonTabs({
    super.key,
    required this.builders,
    required this.selectedIndex,
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AnthemTheme.panel.border, width: 1),
        borderRadius: BorderRadius.circular(4),
        color: AnthemTheme.control.main.lightAccent,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < builders.length * 2 - 1; i++)
              if (i % 2 == 1)
                _Divider(
                  isNextToSelected:
                      i ~/ 2 == selectedIndex || i ~/ 2 + 1 == selectedIndex,
                )
              else
                _ButtonTab(
                  index: i ~/ 2,
                  isSelected: i ~/ 2 == selectedIndex,
                  builder: builders[i ~/ 2],
                  onSelect: () => onChange?.call(i ~/ 2),
                ),
          ],
        ),
      ),
    );
  }
}

class _ButtonTab extends StatefulWidget {
  final int index;
  final bool isSelected;
  final ButtonTabsBuilder builder;
  final VoidCallback onSelect;

  const _ButtonTab({
    required this.index,
    required this.isSelected,
    required this.builder,
    required this.onSelect,
  });

  @override
  State<_ButtonTab> createState() => _ButtonTabState();
}

class _ButtonTabState extends State<_ButtonTab> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        color: widget.isSelected ? AnthemTheme.control.main.darkAccent : null,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() {
            isHovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            isHovered = false;
          });
        },
        child: GestureDetector(
          onTap: widget.onSelect,
          child: Center(
            child: widget.builder(
              context,
              ButtonTabProps(
                isHovered: isHovered,
                isSelected: widget.isSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isNextToSelected;

  const _Divider({required this.isNextToSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Container(
        width: 1,
        color: isNextToSelected ? null : AnthemTheme.panel.border,
      ),
    );
  }
}

class TextButtonTabs extends StatelessWidget {
  final List<({String label, VoidCallback onSelect})> tabs;
  final int selectedIndex;
  final void Function(int index)? onChange;

  const TextButtonTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return ButtonTabs(
      selectedIndex: selectedIndex,
      onChange: onChange,
      builders: tabs.map((tab) {
        return (BuildContext context, ButtonTabProps props) {
          return Text(
            tab.label,
            style: TextStyle(
              color: props.isSelected
                  ? AnthemTheme.primary.main
                  : props.isHovered
                  ? AnthemTheme.text.accent
                  : AnthemTheme.text.main,
              fontSize: 11,
              fontWeight: .w500,
            ),
          );
        };
      }).toList(),
    );
  }
}
