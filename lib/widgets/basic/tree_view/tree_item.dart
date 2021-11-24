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

import 'package:anthem/widgets/basic/tree_view/tree_item_indent.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../theme.dart';

const indentIncrement = 21.0;

class TreeItem extends StatefulWidget {
  final String? label;
  final List<Widget>? children;
  const TreeItem({Key? key, this.label, this.children}) : super(key: key);

  @override
  State<TreeItem> createState() => _TreeItemState();
}

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
                    if ((widget.children?.length ?? 0) > 0) {
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
                    color: isHovered ? Theme.control.hover.dark : null,
                    height: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: indent),
                        widget.children?.isNotEmpty ?? false
                            ? Container(
                                width: 10,
                                height: 10,
                                color: isOpen
                                    ? const Color(0xFFFF0000)
                                    : const Color(0xFFFFFFFF),
                              )
                            : const SizedBox(width: 10),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.label ?? "",
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Theme.text.main),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] +
            ((isOpen ? widget.children : []) ?? []),
      ),
    );
  }
}
