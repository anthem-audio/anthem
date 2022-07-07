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

part of "tree_view.dart";

const indentIncrement = 21.0;

class _TreeItem extends StatefulWidget {
  final String? label;
  final List<TreeViewItemModel> children;
  final bool hasOpenIndicatorIndent;
  final Map<String, _TreeViewItemFilterModel> filterModels;
  final int filterCutoff;

  const _TreeItem({
    Key? key,
    this.label,
    required this.children,
    this.hasOpenIndicatorIndent = false,
    required this.filterModels,
    required this.filterCutoff,
  }) : super(key: key);

  @override
  State<_TreeItem> createState() => _TreeItemState();
}

const double itemHeight = 24;

class _TreeItemState extends State<_TreeItem> with TickerProviderStateMixin {
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

    final hasChildWithChildren = widget.children.fold<bool>(
      false,
      (previousValue, element) => previousValue || element.children.isNotEmpty,
    );

    for (var i = 0; i < widget.children.length; i++) {
      final model = widget.children[i];
      final filterModel = widget.filterModels[model.key];

      if (filterModel == null || filterModel.matchScore > widget.filterCutoff) {
        children.add(
          SizedBox(
            child: _TreeItem(
              label:
                  "${model.label} - ${(widget.filterModels[model.key]?.matchScore.toString() ?? '')}",
              children: model.children,
              hasOpenIndicatorIndent: hasChildWithChildren,
              filterModels: widget.filterModels,
              filterCutoff: widget.filterCutoff,
            ),
          ),
        );
      }
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
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
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
                      SizedBox(
                        width: widget.children.isNotEmpty ||
                                widget.hasOpenIndicatorIndent
                            ? 10
                            : 0,
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
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.label ?? "",
                          textAlign: TextAlign.left,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: Theme.text.main, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
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
