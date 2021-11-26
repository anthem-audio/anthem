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

import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar.dart';
import 'package:anthem/widgets/basic/tree_view/tree_item.dart';
import 'package:anthem/widgets/basic/tree_view/tree_view.dart';
import 'package:flutter/widgets.dart';

import '../../theme.dart';

class ProjectExplorer extends StatefulWidget {
  const ProjectExplorer({Key? key}) : super(key: key);

  @override
  State<ProjectExplorer> createState() => _ProjectExplorerState();
}

class _ProjectExplorerState extends State<ProjectExplorer> {
  final ScrollController controller = ScrollController();

  @override
  void initState() {
    // controller.
    WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
      print(controller.position.maxScrollExtent);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    print("build");
    return Background(
      type: BackgroundType.dark,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 26),
            const SizedBox(height: 4),
            const SizedBox(height: 24),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.panel.accentDark,
                        border: Border.all(color: Theme.panel.border, width: 1),
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: TreeView(
                        scrollController: controller,
                        children: const [
                          TreeItem(label: "Current project", children: [
                            TreeItem(
                              label: "abc",
                              children: [
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                              ],
                            ),
                            TreeItem(label: "abc"),
                            TreeItem(label: "abc"),
                          ]),
                          TreeItem(label: "Recent files"),
                          TreeItem(label: "Plugin databases"),
                          TreeItem(label: "Current project", children: [
                            TreeItem(
                              label: "abc",
                              children: [
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                              ],
                            ),
                            TreeItem(label: "abc"),
                            TreeItem(label: "abc"),
                          ]),
                          TreeItem(label: "Recent files"),
                          TreeItem(label: "Plugin databases"),
                          TreeItem(label: "Current project", children: [
                            TreeItem(
                              label: "abc",
                              children: [
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                              ],
                            ),
                            TreeItem(label: "abc"),
                            TreeItem(label: "abc"),
                          ]),
                          TreeItem(label: "Recent files"),
                          TreeItem(label: "Plugin databases"),
                          TreeItem(label: "Current project", children: [
                            TreeItem(
                              label: "abc",
                              children: [
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                              ],
                            ),
                            TreeItem(label: "abc"),
                            TreeItem(label: "abc"),
                          ]),
                          TreeItem(label: "Recent files"),
                          TreeItem(label: "Plugin databases"),
                          TreeItem(label: "Current project", children: [
                            TreeItem(
                              label: "abc",
                              children: [
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                              ],
                            ),
                            TreeItem(label: "abc"),
                            TreeItem(label: "abc"),
                          ]),
                          TreeItem(label: "Recent files"),
                          TreeItem(label: "Plugin databases"),
                          TreeItem(label: "Current project", children: [
                            TreeItem(
                              label: "abc",
                              children: [
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                              ],
                            ),
                            TreeItem(label: "abc"),
                            TreeItem(label: "abc"),
                          ]),
                          TreeItem(label: "Recent files"),
                          TreeItem(label: "Plugin databases"),
                          TreeItem(label: "Current project", children: [
                            TreeItem(
                              label: "abc",
                              children: [
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                                TreeItem(label: "abc"),
                              ],
                            ),
                            TreeItem(label: "abc"),
                            TreeItem(label: "abc"),
                          ]),
                          TreeItem(label: "Recent files"),
                          TreeItem(label: "Plugin databases"),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                    Scrollbar(
                      controller: controller,
                      direction: ScrollbarDirection.vertical,
                      crossAxisSize: 17,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
