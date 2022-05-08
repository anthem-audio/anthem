/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/helpers/constants.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/tree_view/tree_item_indent.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'model.dart';

const indentIncrement = 21.0;

class TreeItem extends StatefulWidget {
  final String? label;
  final List<TreeViewItemModel> children;
  const TreeItem({
    Key? key,
    this.label,
    required this.children,
  }) : super(key: key);

  @override
  State<TreeItem> createState() => _TreeItemState();
}

const double itemHeight = 24;

class _TreeItemState extends State<TreeItem> with TickerProviderStateMixin {
  bool isHovered = false;
  bool isOpen = false;

  void open() {
    setState(() {
      isOpen = true;
    });
  }

  void close() {
    setState(() {
      isOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final indent = Provider.of<TreeItemIndent>(context).indent;

    final List<Widget> children = [];

    for (var i = 0; i < widget.children.length; i++) {
      final model = widget.children[i];

      children.add(
        SizedBox(
          child: TreeItem(
            label: model.name,
            children: model.children,
          ),
        ),
      );
    }

    return Provider(
      create: (context) => TreeItemIndent(indent: indent + indentIncrement),
      child: Column(
        children: <Widget>[
          MouseRegion(
            onEnter: (e) {
              setState(() {
                isHovered = true;
              });
            },
            onExit: (e) {
              setState(() {
                isHovered = false;
              });
            },
            child: GestureDetector(
              onTap: () {
                if (widget.children.isNotEmpty) {
                  setState(() {
                    if (isOpen) {
                      close();
                    } else {
                      open();
                    }
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isHovered ? Theme.primary.subtle : null,
                  border: Border.all(
                    color: isHovered
                        ? Theme.primary.subtleBorder
                        : const Color(0x00000000),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                height: itemHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: indent),
                    widget.children.isNotEmpty
                        ? SizedBox(
                            width: 10,
                            height: 10,
                            child: (widget.children.isEmpty)
                                ? null
                                : Transform.rotate(
                                    angle: isOpen ? 0 : -pi / 2,
                                    alignment: Alignment.center,
                                    child: SvgIcon(
                                      icon: Icons.arrowDown,
                                      color: Theme.text.main,
                                    ),
                                  ),
                          )
                        : const SizedBox(width: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label ?? "",
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.text.main, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Visibility(
            visible: isOpen,
            maintainState: true,
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
