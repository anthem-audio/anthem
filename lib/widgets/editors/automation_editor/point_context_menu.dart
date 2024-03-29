/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/editors/automation_editor/controller/automation_editor_controller.dart';
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class AutomationPointContextMenu extends StatelessWidget {
  final Widget? child;

  const AutomationPointContextMenu({this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AutomationEditorViewModel>(context);
    final controller = Provider.of<AutomationEditorController>(context);

    return Menu(
      menuController: viewModel.pointMenuController,
      menuDef: viewModel.pointMenu,
      onClose: () => controller.pointMenuClosed(),
      child: child,
    );
  }
}
