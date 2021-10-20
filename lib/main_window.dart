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
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/panel.dart';
import 'package:anthem/window_header.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:anthem/main_window_cubit.dart';

class MainWindow extends StatefulWidget {
  final Store _store;

  MainWindow(this._store, {Key? key}) : super(key: key);

  @override
  _MainWindowState createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  bool isTestMenuOpen = false;
  MenuController menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainWindowCubit, MainWindowState>(
        builder: (context, state) {
      return Padding(
        padding: EdgeInsets.all(3),
        child: Column(
          children: [
            WindowHeader(
              selectedTabID: state.selectedTabID,
              tabs: state.tabs,
              setActiveProject: (int id) {
                context.read<MainWindowCubit>().switchTab(id);
              },
            ),
            Container(
              height: 42,
              color: Theme.panel.accent,
            ),
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
      );
    });
  }
}
