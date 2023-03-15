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

import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';

class ToolSelector extends StatelessWidget {
  final EditorTool selectedTool;
  final Function(EditorTool)? setTool;

  const ToolSelector({Key? key, required this.selectedTool, this.setTool})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 39,
      child: Dropdown(
        showNameOnButton: false,
        allowNoSelection: false,
        selectedID: EditorTool.values
            .firstWhere(
              (tool) => tool.name == selectedTool.name,
            )
            .name,
        items: [
          DropdownItem(
            id: EditorTool.pencil.name,
            name: 'Pencil',
            icon: Icons.tools.pencil,
          ),
          DropdownItem(
            id: EditorTool.eraser.name,
            name: 'Eraser',
            icon: Icons.tools.erase,
          ),
          DropdownItem(
            id: EditorTool.select.name,
            name: 'Select',
            icon: Icons.tools.select,
          ),
          DropdownItem(
            id: EditorTool.cut.name,
            name: 'Cut',
            icon: Icons.tools.cut,
          ),
        ],
        onChanged: (id) {
          setTool?.call(
            EditorTool.values.firstWhere(
              (tool) => tool.name == id,
            ),
          );
        },
      ),
    );
  }
}
