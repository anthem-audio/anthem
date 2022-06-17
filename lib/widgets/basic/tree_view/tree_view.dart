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

import 'package:anthem/widgets/basic/tree_view/tree_item.dart';
import 'package:anthem/widgets/basic/tree_view/tree_item_indent.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'model.dart';

const baseIndent = 20.0;

class TreeView extends StatelessWidget {
  final List<TreeViewItemModel> items;
  final ScrollController? scrollController;

  const TreeView({Key? key, required this.items, this.scrollController})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (context) => TreeItemIndent(indent: baseIndent),
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          WidgetsBinding.instance.addPostFrameCallback((duration) {
            scrollController?.position.notifyListeners();
          });
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: SingleChildScrollView(
            controller: scrollController,
            child: SizeChangedLayoutNotifier(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items
                    .map(
                      (item) => TreeItem(
                        label: item.name,
                        children: item.children,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
