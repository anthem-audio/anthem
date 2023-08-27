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

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/widgets.dart';
import 'main_window_controller.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/project/project.dart';

/// This widget takes a list of tabs and a selected tab ID, and renders the
/// active project based on it.
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
      children: tabs.map(
        (tab) {
          final active = tab.id == selectedTabID;
          return Positioned.fill(
            child: ShortcutProvider(
              active: active,
              child: Visibility(
                visible: active,
                maintainState: true,
                child: Project(id: tab.id),
              ),
            ),
          );
        },
      ).toList(),
    );
  }
}
