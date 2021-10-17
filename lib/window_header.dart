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
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

class WindowHeader extends StatefulWidget {
  final Store _store;

  WindowHeader(this._store, {Key? key}) : super(key: key);

  @override
  _WindowHeaderState createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  @override
  Widget build(BuildContext context) {
    final store = widget._store;

    return SizedBox(
      height: 37,
      child: Row(
        children: store.projects.map<Widget>(
              (project) {
                final isActiveProject = project.id == store.activeProjectId;
                return GestureDetector(
                  onTap: () {
                    store.msgSetActiveProject(project.id).then((reply) {
                      setState(() {});
                    });
                  },
                  child: Padding(
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
                    ),
                    padding: EdgeInsets.only(
                        right: 1, bottom: isActiveProject ? 0 : 1),
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
