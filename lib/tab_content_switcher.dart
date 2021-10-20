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

import 'package:anthem/project_header.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/panel.dart';
import 'package:flutter/widgets.dart';

import 'main_window_cubit.dart';

class TabContentSwitcher extends StatelessWidget {
  final List<TabDef> tabs;
  final int selectedTabID;

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
                child: Column(
                  children: [
                    ProjectHeader(),
                    SizedBox(
                      height: 3,
                    ),
                    Expanded(
                      child: Panel(
                        orientation: PanelOrientation.Left,
                        child: Panel(
                          orientation: PanelOrientation.Right,
                          child: Container(
                            color: Color(0x55FF0000),
                          ),
                          panelContent: Container(
                            color: Color(0x5500FF00),
                          ),
                        ),
                        panelContent: Container(
                          color: Color(0x5500FF00),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 3,
                    ),
                    Container(
                      height: 42,
                      color: Theme.panel.light,
                    )
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
