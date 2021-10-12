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
import 'package:anthem/window_header.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

class MainWindow extends StatefulWidget {
  final Store _store;

  MainWindow(this._store, {Key? key}) : super(key: key);

  @override
  _MainWindowState createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(3),
      child: Column(
        children: [
          WindowHeader(widget._store),
          Container(
            height: 42,
            color: Theme.panel.accent,
          ),
          SizedBox(
            height: 3,
          ),
          Expanded(
            child: Container(
            color: Theme.panel.main,
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
  }
}
