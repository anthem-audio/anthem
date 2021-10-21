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
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'main_window_cubit.dart';

class ProjectHeader extends StatelessWidget {
  final int projectID;

  const ProjectHeader({Key? key, required this.projectID}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainWindowCubit, MainWindowState>(
        builder: (context, state) {
      final menuController = MenuController();
      final cubit = context.read<MainWindowCubit>();

      return Container(
        height: 42,
        color: Theme.panel.accent,
        child: Padding(
          padding: EdgeInsets.all(7),
          child: Row(
            children: [
              Menu(
                menuController: menuController,
                menuDef: MenuDef(
                  children: [
                    MenuItem(
                        text: "New Project",
                        onSelected: () {
                          cubit
                              .newProject()
                              .then((projectID) => cubit.switchTab(projectID));
                        }),
                  ],
                ),
                child: Button(
                  width: 28,
                  iconPath: "assets/icons/file/hamburger.svg",
                  onPress: () {
                    print("press " + projectID.toString());
                    print(menuController.open == null);
                    menuController.open?.call();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
