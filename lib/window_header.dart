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
import 'package:flutter/widgets.dart';

import 'widgets/main_window/main_window_cubit.dart';

class WindowHeader extends StatefulWidget {
  final int selectedTabID;
  final List<TabDef> tabs;
  final Function(int) setActiveProject;
  final Function(int) closeProject;

  WindowHeader({
    Key? key,
    required this.selectedTabID,
    required this.tabs,
    required this.setActiveProject,
    required this.closeProject,
  }) : super(key: key);

  @override
  _WindowHeaderState createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 37,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.tabs.map<Widget>(
              (tab) {
                final isActiveProject = tab.id == widget.selectedTabID;
                return GestureDetector(
                  onTap: () {
                    widget.setActiveProject(tab.id);
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: 1, bottom: isActiveProject ? 0 : 1),
                    child: Container(
                      width: 125,
                      decoration: BoxDecoration(
                        color: isActiveProject
                            ? Theme.panel.accent
                            : Theme.panel.main,
                        borderRadius: isActiveProject
                            ? BorderRadius.only(
                                topLeft: Radius.circular(2),
                                topRight: Radius.circular(2))
                            : BorderRadius.all(
                                Radius.circular(2),
                              ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tab.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.text.main),
                            ),
                          ),
                          Button(
                            width: 20,
                            height: 20,
                            iconPath: "assets/icons/small/close.svg",
                            onPress: () {
                              widget.closeProject(tab.id);
                            },
                          ),
                          SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ).toList() +
            [
              Expanded(
                child: Padding(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.panel.main,
                      borderRadius: BorderRadius.all(
                        Radius.circular(2),
                      ),
                    ),
                  ),
                  padding: EdgeInsets.only(bottom: 1),
                ),
              ),
            ],
      ),
    );
  }
}
