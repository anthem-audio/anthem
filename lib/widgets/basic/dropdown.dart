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

import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';

import 'button.dart';
import 'icon.dart';
import 'menu/menu.dart';
import 'menu/menu_model.dart';

class Dropdown extends StatefulWidget {
  final double? width;
  final double? height;
  final String? selectedID;
  final List<DropdownItem> items;
  final Function(String?)? onChanged;
  final bool showNameOnButton;
  final String? hint;

  /// Whether or not to add a (none) option to the dropdown
  final bool allowNoSelection;

  const Dropdown({
    super.key,
    this.width,
    this.height,
    this.selectedID,
    this.items = const [],
    this.onChanged,
    this.showNameOnButton = true,
    this.allowNoSelection = true,
    this.hint,
  });

  @override
  State<Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<Dropdown> {
  String? localSelectedID;
  bool hovered = false;

  @override
  void didUpdateWidget(Dropdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (hovered && oldWidget.selectedID != widget.selectedID) {
      final item = widget.items
          .firstWhereOrNull((element) => element.id == widget.selectedID);

      final projectController =
          Provider.of<ProjectController>(context, listen: false);

      if (item != null) {
        projectController.setHintText(item.hint ?? '');
      } else {
        projectController.clearHintText();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuController = MenuController();
    final selectedID = widget.selectedID ?? localSelectedID;

    final selectedItem = widget.items.firstWhere(
      (element) => element.id == selectedID,
      orElse: () => const DropdownItem(id: '', name: '(none)'),
    );

    return Menu(
      menuController: menuController,
      menuDef: MenuDef(
        children: widget.items
                .map<GenericMenuItem>(
                  (item) => AnthemMenuItem(
                    text: item.name ?? '',
                    hint: item.hint ?? '',
                    onSelected: () => select(item.id),
                  ),
                )
                .toList() +
            (!widget.allowNoSelection
                ? []
                : [
                    widget.items.isNotEmpty ? Separator() : null,
                    AnthemMenuItem(
                      text: '(none)',
                      onSelected: () => select(null),
                    )
                  ].whereNotNull().toList()),
      ),
      child: MouseRegion(
        // No need to setState since we're not reacting to these
        onEnter: (e) {
          hovered = true;
        },
        onExit: (e) {
          hovered = false;
        },

        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              // How many items to scroll by on this event
              final itemIndexDelta = (event.scrollDelta.dy / 100).ceil();

              final selectedID = selectedItem.id;
              var selectedIndex = widget.items
                  .indexWhere((element) => element.id == selectedID);

              // If we didn't find it, then we can probably assume there is no
              // selected item.
              if (selectedIndex < 0) {
                selectedIndex = widget.items.length;
              }

              var itemCount = widget.items.length;

              if (widget.allowNoSelection) itemCount++;

              var newIndex = (selectedIndex + itemIndexDelta) % itemCount;

              if (newIndex < 0) newIndex += itemCount;

              if (newIndex == widget.items.length) {
                select(null);
              } else {
                select(widget.items[newIndex].id);
              }
            }
          },
          child: Button(
            onPress: () {
              menuController.open();
            },
            width: widget.width,
            height: widget.height,
            contentBuilder: (context, contentColor) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (selectedItem.icon != null)
                    SvgIcon(
                      icon: selectedItem.icon!,
                      color: contentColor,
                    ),
                  Expanded(
                    child: Text(
                      (widget.showNameOnButton ? selectedItem.name : null) ??
                          '',
                      style: TextStyle(
                        color: contentColor,
                        fontSize: 11,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SvgIcon(
                    icon: Icons.arrowDown,
                    color: contentColor,
                  ),
                ],
              );
            },
            hint: widget.hint,
          ),
        ),
      ),
    );
  }

  void select(String? id) {
    setState(() {
      localSelectedID = id;
    });
    widget.onChanged?.call(id);
  }
}

@immutable
class DropdownItem {
  final String id;
  final String? name;
  final IconDef? icon;
  final String? hint;

  const DropdownItem({
    required this.id,
    this.name,
    this.icon,
    this.hint,
  });
}
