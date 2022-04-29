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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/widgets.dart';

import '../basic/icon.dart';
import 'main_window_cubit.dart';

class WindowHeader extends StatefulWidget {
  final ID selectedTabID;
  final List<TabDef> tabs;
  final Function(ID) setActiveProject;
  final Function(ID) closeProject;

  const WindowHeader({
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
    var isFirstTab = true;

    return SizedBox(
      height: 29,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.tabs.map<Widget>(
              (tab) {
                final isActiveProject = tab.id == widget.selectedTabID;
                final result = GestureDetector(
                  onTap: () {
                    widget.setActiveProject(tab.id);
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: 1, bottom: isActiveProject ? 0 : 1),
                    child: Container(
                      width: 115,
                      decoration: BoxDecoration(
                        color: isActiveProject
                            ? Theme.panel.accent
                            : Theme.panel.main,
                        borderRadius: isActiveProject
                            ? BorderRadius.only(
                                topLeft: Radius.circular(isFirstTab ? 4 : 2),
                                topRight: const Radius.circular(2))
                            : BorderRadius.only(
                                // TODO: This should only be on the logo button, but we don't have one yet
                                topLeft: Radius.circular(isFirstTab ? 4 : 1),
                                topRight: const Radius.circular(1),
                                bottomRight: const Radius.circular(1),
                                bottomLeft: const Radius.circular(1),
                              ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tab.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.text.main),
                            ),
                          ),
                          Button(
                            variant: ButtonVariant.ghost,
                            width: 22,
                            height: 22,
                            hideBorder: true,
                            startIcon: Icons.close,
                            onPress: () {
                              widget.closeProject(tab.id);
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                );

                isFirstTab = false;

                return result;
              },
            ).toList() +
            [
              Expanded(
                child: MoveWindow(
                  child: Padding(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.panel.main,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          topLeft: Radius.circular(2),
                          bottomLeft: Radius.circular(1),
                          bottomRight: Radius.circular(1),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(bottom: 1),
                  ),
                ),
              ),
            ],
      ),
    );
  }
}
