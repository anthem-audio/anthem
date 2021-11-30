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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/main_window/main_window_cubit.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../main_window/main_window_cubit.dart';

class ProjectHeader extends StatelessWidget {
  final int projectID;

  const ProjectHeader({Key? key, required this.projectID}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectCubit, ProjectState>(builder: (context, state) {
      final menuController = MenuController();
      final mainWindowCubit = context.read<MainWindowCubit>();
      final projectCubit = context.read<ProjectCubit>();

      return Container(
        height: 40,
        color: Theme.panel.accent,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              Menu(
                menuController: menuController,
                menuDef: MenuDef(
                  children: [
                    MenuItem(
                        text: "New project",
                        onSelected: () {
                          mainWindowCubit.newProject().then((projectID) {
                            mainWindowCubit.switchTab(projectID);
                            print(projectID);
                          });
                        }),
                    MenuItem(
                        text: "Load project...",
                        onSelected: () {
                          mainWindowCubit.loadProject().then((projectID) {
                            if (projectID != null) {
                              mainWindowCubit.switchTab(projectID);
                            }
                          });
                        }),
                    Separator(),
                    MenuItem(
                        text: "Save",
                        onSelected: () {
                          mainWindowCubit.saveProject(projectID, false);
                        }),
                    MenuItem(
                        text: "Save as...",
                        onSelected: () {
                          mainWindowCubit.saveProject(projectID, true);
                        }),
                  ],
                ),
                child: Button(
                  width: 28,
                  iconPath: "assets/icons/file/hamburger.svg",
                  showMenuIndicator: true,
                  onPress: () {
                    menuController.open?.call();
                  },
                ),
              ),
              const SizedBox(width: 4),
              Button(
                width: 28,
                iconPath: "assets/icons/file/save.svg",
                onPress: () {
                  mainWindowCubit.saveProject(projectID, false);
                },
              ),
              const SizedBox(width: 4),
              Button(
                width: 28,
                iconPath: "assets/icons/file/undo.svg",
                onPress: () {
                  projectCubit.undo();
                },
              ),
              const SizedBox(width: 4),
              Button(
                width: 28,
                iconPath: "assets/icons/file/redo.svg",
                onPress: () {
                  projectCubit.redo();
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}
