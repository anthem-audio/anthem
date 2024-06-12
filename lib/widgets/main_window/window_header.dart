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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/main_window/window_header_engine_indicator.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'main_window_controller.dart';

class WindowHeader extends StatefulWidget {
  final ID selectedTabID;
  final List<TabDef> tabs;

  const WindowHeader({
    super.key,
    required this.selectedTabID,
    required this.tabs,
  });

  @override
  State<WindowHeader> createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 29,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(bottom: 1),
                child: EngineIndicator(),
              ),
              const SizedBox(width: 1),
            ] +
            widget.tabs
                .map<Widget>(
                  (tab) => _Tab(
                    isSelected: tab.id == widget.selectedTabID,
                    id: tab.id,
                    title: tab.title,
                  ),
                )
                .toList() +
            [
              Expanded(
                child: MoveWindow(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 1),
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
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          children: [
                            const Expanded(child: SizedBox()),
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 4, right: 4, bottom: 4),
                              child: Button(
                                width: 20,
                                height: 20,
                                contentPadding: const EdgeInsets.all(2),
                                variant: ButtonVariant.ghost,
                                hideBorder: true,
                                icon: Icons.minimize,
                                onPress: () {
                                  appWindow.minimize();
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 4, right: 4, bottom: 4),
                              child: Button(
                                width: 20,
                                height: 20,
                                contentPadding: const EdgeInsets.all(2),
                                variant: ButtonVariant.ghost,
                                hideBorder: true,
                                icon: Icons.maximize,
                                onPress: () {
                                  appWindow.maximizeOrRestore();
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 4, right: 4, bottom: 4),
                              child: Button(
                                width: 20,
                                height: 20,
                                contentPadding: const EdgeInsets.all(2),
                                variant: ButtonVariant.ghost,
                                hideBorder: true,
                                icon: Icons.close,
                                onPress: () {
                                  appWindow.close();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final bool isSelected;
  final ID id;
  final String title;

  const _Tab({
    required this.isSelected,
    required this.id,
    required this.title,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool closePressed = false;

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MainWindowController>(context);

    final result = GestureDetector(
      onTap: () {
        if (!closePressed) {
          controller.switchTab(widget.id);
        }
        closePressed = false;
      },
      child: Padding(
        padding: EdgeInsets.only(
          right: 1,
          bottom: widget.isSelected ? 0 : 1,
        ),
        child: Container(
          width: 115,
          decoration: BoxDecoration(
            color: widget.isSelected ? Theme.panel.accent : Theme.panel.main,
            borderRadius: widget.isSelected
                ? const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(2),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(1),
                    topRight: Radius.circular(1),
                    bottomRight: Radius.circular(1),
                    bottomLeft: Radius.circular(1),
                  ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: widget.isSelected ? 1 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.text.main),
                  ),
                ),
                Button(
                  variant: ButtonVariant.ghost,
                  width: 22,
                  height: 22,
                  hideBorder: true,
                  icon: Icons.close,
                  onPress: () {
                    closePressed = true;
                    controller.closeProject(widget.id);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );

    return result;
  }
}
