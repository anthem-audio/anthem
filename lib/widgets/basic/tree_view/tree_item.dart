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

import 'package:anthem/widgets/basic/tree_view/tree_item_indent.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

const indentIncrement = 21.0;

class TreeItem extends StatelessWidget {
  final String? label;
  final List<Widget>? children;
  const TreeItem({Key? key, this.label, this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final indent = Provider.of<TreeItemIndent>(context).indent;

    return Provider(
      create: (context) => TreeItemIndent(indent: indent + indentIncrement),
      child: Column(
        children: <Widget>[
              Padding(
                padding: EdgeInsets.only(left: indent),
                child: Container(
                  color: const Color(0xFF00FF00),
                  height: 24,
                ),
              ),
            ] +
            (children ?? []),
      ),
    );
  }
}
