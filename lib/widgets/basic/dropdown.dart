/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'button.dart';
import 'icon.dart';
import 'menu/menu.dart';
import 'menu/menu_model.dart';

class Dropdown extends StatefulWidget {
  final double? width;
  final double? height;
  final String? selectedID;
  final List<DropdownItem> items;
  final void Function(String?)? onChanged;
  final bool showNameOnButton;
  final String? hint;
  final EdgeInsets? contentPadding;
  final bool horizontalExpand;

  /// Whether or not to add a (none) option to the dropdown
  final bool allowNoSelection;

  /// Whether the menu can be opened and its selection changed.
  final bool enabled;
  final ButtonVariant? variant;
  final bool? hideBorder;

  /// Whether the mouse wheel cycles through options.
  final bool enableScrollSelection;

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
    this.contentPadding,
    this.horizontalExpand = true,
    this.enabled = true,
    this.variant,
    this.hideBorder,
    this.enableScrollSelection = true,
  });

  @override
  State<Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<Dropdown> {
  final menuController = AnthemMenuController();
  String? localSelectedID;
  bool _menuOpen = false;

  @override
  void didUpdateWidget(Dropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _closeMenu();
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    _menuOpen = false;
    menuController.close();
  }

  @override
  Widget build(BuildContext context) {
    final selectedID = widget.selectedID ?? localSelectedID;

    final selectedItem = widget.items.firstWhere(
      (element) => element.id == selectedID,
      orElse: () => const DropdownItem(id: '', name: '(none)'),
    );

    return Menu(
      menuController: menuController,
      onClose: () => _menuOpen = false,
      menuDef: MenuDef(
        children:
            widget.items
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
                    ),
                  ].nonNulls.toList()),
      ),
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent &&
                widget.enabled &&
                widget.enableScrollSelection) {
              // How many items to scroll by on this event
              final itemIndexDelta = (event.scrollDelta.dy / 100).ceil();

              final selectedID = selectedItem.id;
              var selectedIndex = widget.items.indexWhere(
                (element) => element.id == selectedID,
              );

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
              menuController.toggle();
              _menuOpen = menuController.isOpen;
            },
            width: widget.width,
            height: widget.height,
            variant: widget.variant,
            hideBorder: widget.hideBorder,
            interactable: widget.enabled,
            contentPadding:
                widget.contentPadding ??
                const EdgeInsets.symmetric(horizontal: 2),
            contentBuilder: (context, contentColor) {
              final text = widget.showNameOnButton ? selectedItem.name : null;
              final textWidget = text != null
                  ? Text(
                      text,
                      style: TextStyle(
                        color: contentColor,
                        fontSize: 11,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (selectedItem.icon != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SvgIcon(
                        icon: selectedItem.icon!,
                        color: contentColor,
                      ),
                    ),
                  if (text != null) const SizedBox(width: 2),
                  if (widget.horizontalExpand)
                    Expanded(child: textWidget ?? const SizedBox())
                  else
                    ?textWidget,
                  if (!widget.horizontalExpand) SizedBox(width: 4),
                  SvgIcon(icon: Icons.arrowDown, color: contentColor),
                  SizedBox(width: 2),
                ],
              );
            },
            hint: [if (widget.hint != null) HintSection('click', widget.hint!)],
          ),
        ),
      ),
    );
  }

  void select(String? id) {
    if (!mounted || !widget.enabled) return;
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

  const DropdownItem({required this.id, this.name, this.icon, this.hint});
}
