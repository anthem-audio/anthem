/*
  Copyright (C) 2022 Joshua Wade

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

part of 'tree_view.dart';

class _TreeViewItemFilterModel {
  TreeViewItemModel item;
  int rawMatchScore;
  int maxScoreOfChildren;
  bool hasHighestScore = false;

  _TreeViewItemFilterModel({
    required this.item,
    required this.rawMatchScore,
    required this.maxScoreOfChildren,
  });
}

class TreeViewItemModel {
  List<TreeViewItemModel> children;
  String label;
  Function? onClick;

  /// Key for this item. Must be unique within this tree view.
  String key;

  TreeViewItemModel({
    required this.key,
    required this.label,
    this.children = const [],
    this.onClick,
  });
}
