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

import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/main_window/main_window_controller.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay.dart';
import 'package:anthem/widgets/main_window/tab_content_switcher.dart';
import 'package:anthem/widgets/main_window/window_header.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({Key? key}) : super(key: key);

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  bool isTestMenuOpen = false;
  MenuController menuController = MenuController();
  MainWindowController controller = MainWindowController();

  @override
  Widget build(BuildContext context) {
    final store = AnthemStore.instance;

    return Provider.value(
      value: controller,
      child: ShortcutProvider(
        child: ScreenOverlay(
          child: Container(
            color: const Color(0xFF2A3237),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Observer(builder: (context) {
                final tabs = store.projectOrder
                    .map<TabDef>(
                      (projectID) => TabDef(
                        id: projectID,
                        title: store.projects[projectID]!.id,
                      ),
                    )
                    .toList();

                return Column(
                  children: [
                    WindowHeader(
                      selectedTabID: store.activeProjectID,
                      tabs: tabs,
                    ),
                    Expanded(
                      child: TabContentSwitcher(
                        tabs: tabs,
                        selectedTabID: store.activeProjectID,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
