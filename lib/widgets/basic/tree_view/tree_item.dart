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

part of 'tree_view.dart';

const indentIncrement = 21.0;

class _TreeItem extends StatefulWidget {
  final TreeViewItemModel model;
  final bool hasOpenIndicatorIndent;
  final _TreeViewItemFilterModel? filterModel;
  final Map<String, _TreeViewItemFilterModel> allFilterModels;
  final int filterCutoff;

  const _TreeItem({
    Key? key,
    required this.model,
    this.hasOpenIndicatorIndent = false,
    required this.filterModel,
    required this.allFilterModels,
    required this.filterCutoff,
  }) : super(key: key);

  @override
  State<_TreeItem> createState() => _TreeItemState();
}

const double itemHeight = 24;

class _TreeItemState extends State<_TreeItem> with TickerProviderStateMixin {
  bool isHovered = false;
  bool isOpenFlag = false;
  bool get isOpen => isOpenFlag || widget.allFilterModels.isNotEmpty;

  void open() {
    setState(() {
      isOpenFlag = true;
    });
  }

  void close() {
    setState(() {
      isOpenFlag = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final indent = Provider.of<TreeItemIndent>(context).indent;

    final List<Widget> children = [];

    final hasChildWithChildren = widget.model.children.fold<bool>(
      false,
      (previousValue, element) => previousValue || element.children.isNotEmpty,
    );

    for (var i = 0; i < widget.model.children.length; i++) {
      final model = widget.model.children[i];
      final filterModel = widget.allFilterModels[model.key];

      children.add(
        SizedBox(
          child: Visibility(
            maintainState: true,
            visible: filterModel == null ||
                filterModel.maxScoreOfChildren > widget.filterCutoff,
            child: _TreeItem(
              model: model,
              hasOpenIndicatorIndent: hasChildWithChildren,
              allFilterModels: widget.allFilterModels,
              filterModel: filterModel,
              filterCutoff: widget.filterCutoff,
            ),
          ),
        ),
      );
    }

    final hasHighestScore = (widget.filterModel?.hasHighestScore ?? false);

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
              onTapDown: (event) {
                if (widget.model.children.isNotEmpty) {
                  setState(() {
                    if (isOpen) {
                      close();
                    } else {
                      open();
                    }
                  });
                } else {
                  widget.model.onClick?.call();
                }
              },
              onDoubleTap: widget.model.children.isNotEmpty &&
                      widget.model.onClick != null
                  ? () => widget.model.onClick?.call()
                  : null,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    color: isHovered || hasHighestScore
                        ? Theme.primary.subtle
                        : null,
                    border: Border.all(
                      color: isHovered
                          ? Theme.primary.subtleBorder
                          : const Color(0x00000000),
                    ),
                    borderRadius: !isHovered && hasHighestScore
                        ? null
                        : BorderRadius.circular(4),
                  ),
                  height: itemHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: indent),
                      SizedBox(
                        width: widget.model.children.isNotEmpty ||
                                widget.hasOpenIndicatorIndent
                            ? 10
                            : 0,
                        height: 10,
                        child: (widget.model.children.isEmpty)
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
                          widget.model.label,
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
