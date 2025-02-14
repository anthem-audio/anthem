/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'dart:math';

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/tree_view/tree_item_indent.dart';
import 'package:flutter/widgets.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:provider/provider.dart';

part 'model.dart';
part 'tree_item.dart';

const baseIndent = 20.0;

class TreeView extends StatefulWidget {
  final String? filterText;
  final List<TreeViewItemModel> items;
  final ScrollController? scrollController;
  final int filterCutoff;

  const TreeView({
    super.key,
    required this.items,
    this.scrollController,
    this.filterText,
    this.filterCutoff = 50,
  });

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> {
  Map<String, _TreeViewItemFilterModel> filterItems = {};

  /// Recalculates `filterItems`.
  ///
  /// This function does not call `setState()` since it's only called on
  /// `didUpdateWidget()`, and the widget will always render after
  /// `didUpdateWidget()` is called.
  void updateFilter() {
    if (widget.filterText == null) {
      filterItems = {};
      return;
    }

    Map<String, _TreeViewItemFilterModel> newFilterItems = {};

    /// Processes a list of `TreeViewItemModel`s, adding a score for each item
    /// in `newFilterItems`. This function also recursively processes the
    /// children of each item, and it returns the highest score it sees.
    int process(List<TreeViewItemModel> items) {
      int highestScore = 0;

      for (final item in items) {
        if (newFilterItems.containsKey(item.key)) {
          throw Exception(
            'Found duplicate key "${item.key}" (label: "${item.label}") '
            'in TreeView. This item duplicates a previous item with the same '
            'key "${item.key}" (label: "${newFilterItems[item.key]?.item.label}").',
          );
        }

        final thisScore = weightedRatio(item.label, widget.filterText!);

        final maxScoreOfChildren = process(item.children);
        final maxOfBoth = max(thisScore, maxScoreOfChildren);

        newFilterItems[item.key] = _TreeViewItemFilterModel(
          item: item,
          rawMatchScore: thisScore,
          maxScoreOfChildren: maxOfBoth,
        );

        highestScore = max(maxOfBoth, highestScore);
      }

      return highestScore;
    }

    int overallHighestScore = process(widget.items);

    for (final item in newFilterItems.values) {
      item.hasHighestScore = item.rawMatchScore >= overallHighestScore;
    }

    filterItems = newFilterItems;
  }

  @override
  void initState() {
    updateFilter();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TreeView oldWidget) {
    if (oldWidget.items != widget.items ||
        oldWidget.filterText != widget.filterText) {
      updateFilter();
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (context) => TreeItemIndent(indent: baseIndent),
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          WidgetsBinding.instance.addPostFrameCallback((duration) {
            widget.scrollController?.position.notifyListeners();
          });
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            child: SizeChangedLayoutNotifier(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    widget.items.map((item) {
                      final filterItem = filterItems[item.key];
                      final visible =
                          filterItem == null ||
                          filterItem.maxScoreOfChildren > widget.filterCutoff;

                      return Visibility(
                        maintainState: true,
                        visible: visible,
                        child: _TreeItem(
                          model: item,
                          allFilterModels: filterItems,
                          filterModel: filterItem,
                          filterCutoff: widget.filterCutoff,
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
