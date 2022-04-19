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

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:collection/collection.dart';

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
  /// Whether or not to add a (none) option to the dropdown
  final bool allowNoSelection;

  const Dropdown({
    Key? key,
    this.width,
    this.height,
    this.selectedID,
    this.items = const [],
    this.onChanged,
    this.showNameOnButton = true,
    this.allowNoSelection = true,
  }) : super(key: key);

  @override
  State<Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<Dropdown> {
  String? localSelectedID;

  @override
  Widget build(BuildContext context) {
    final menuController = MenuController();
    final selectedID = widget.selectedID ?? localSelectedID;

    final selectedItem = widget.items.firstWhere(
      (element) => element.id == selectedID,
      orElse: () => const DropdownItem(id: "", name: "(none)"),
    );

    return Menu(
        menuController: menuController,
        menuDef: MenuDef(
          children: widget.items
                  .map<GenericMenuItem>((item) => MenuItem(
                      text: item.name,
                      onSelected: () {
                        setState(() {
                          localSelectedID = item.id;
                        });
                        widget.onChanged?.call(item.id);
                      }))
                  .toList() +
              (!widget.allowNoSelection
                  ? []
                  : [
                      widget.items.isNotEmpty ? Separator() : null,
                      MenuItem(
                        text: "(none)",
                        onSelected: () {
                          setState(() {
                            localSelectedID = null;
                          });
                          widget.onChanged?.call(null);
                        },
                      )
                    ].whereNotNull().toList()),
        ),
        child: Button(
          onPress: () {
            menuController.open?.call();
          },
          width: widget.width,
          height: widget.height,
          text: widget.showNameOnButton ? selectedItem.name : null,
          startIcon: selectedItem.icon,
          endIcon: Icons.arrowDown,

          // child: Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 9),
          //   child: Row(
          //     crossAxisAlignment: CrossAxisAlignment.center,
          //     children: [
          //       Expanded(
          //         child: Text(
          //           widget.items
          //               .firstWhere((element) => element.id == selectedID,
          //                   orElse: () =>
          //                       const DropdownItem(id: "", name: "(none)"))
          //               .name,
          //           style: TextStyle(
          //             color: Theme.text.main,
          //             overflow: TextOverflow.ellipsis,
          //           ),
          //         ),
          //       ),
          //       SvgPicture.asset(
          //         "assets/icons/small/arrow-down-selectbtn.svg",
          //         color: Theme.text.main,
          //       ),
          //     ],
          //   ),
          // ),
        ));
  }
}

@immutable
class DropdownItem {
  final String id;
  final String? name;
  final IconDef? icon;

  const DropdownItem({required this.id, this.name, this.icon});
}
