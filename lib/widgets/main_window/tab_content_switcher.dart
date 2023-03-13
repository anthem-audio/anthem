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

import 'package:flutter/widgets.dart';
import 'main_window_controller.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/project/project.dart';

class TabContentSwitcher extends StatelessWidget {
  final List<TabDef> tabs;
  final ID selectedTabID;

  const TabContentSwitcher({
    Key? key,
    required this.tabs,
    required this.selectedTabID,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: tabs
          .map(
            (tab) => Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Visibility(
                visible: tab.id == selectedTabID,
                maintainAnimation: false,
                maintainInteractivity: false,
                maintainSemantics: false,
                maintainSize: false,
                maintainState: true,
                child: Project(id: tab.id),
              ),
            ),
          )
          .toList(),
    );
  }
}
