/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class AddChannelMenu extends StatelessWidget {
  final AnthemMenuController menuController;
  final Widget? child;

  const AddChannelMenu({super.key, required this.menuController, this.child});

  @override
  Widget build(BuildContext context) {
    final projectController = Provider.of<ProjectController>(context);

    final menuDef = MenuDef(
      children: [
        AnthemMenuItem(
          text: 'Add automation channel',
          onSelected: () {
            projectController.addGenerator(
              node: NodeModel.uninitialized(),
              name: 'Blank Automation Channel',
              generatorType: GeneratorType.automation,
              color: getColor(),
            );
          },
        ),
        AnthemMenuItem(
          text: 'Add instrument channel',
          submenu: MenuDef(
            children: [
              AnthemMenuItem(
                text: 'Tone Generator',
                onSelected: () {
                  projectController.addGenerator(
                    node: ToneGeneratorProcessorModel.createNode(),
                    name: 'Tone Generator',
                    generatorType: GeneratorType.instrument,
                    color: getColor(),
                  );
                },
              ),
              Separator(),
              AnthemMenuItem(
                text: 'VST3...',
                onSelected: () {
                  projectController.addVst3Generator();
                },
              ),
              AnthemMenuItem(
                text: 'Blank',
                onSelected: () {
                  projectController.addGenerator(
                    node: NodeModel.uninitialized(),
                    name: 'Blank Instrument',
                    generatorType: GeneratorType.instrument,
                    color: getColor(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );

    return Menu(menuController: menuController, menuDef: menuDef, child: child);
  }
}
