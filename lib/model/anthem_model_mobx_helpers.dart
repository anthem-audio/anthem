/*
  Copyright (C) 2025 Joshua Wade

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

import 'package:anthem/model/anthem_model_base_mixin.dart';

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

/// This class defines information about the currently-active watch all builder.
class AnthemModelMobXWatchAllItem {
  AnthemModelBase item;
  Atom atom;

  AnthemModelMobXWatchAllItem({required this.item, required this.atom});
}

AnthemModelMobXWatchAllItem? currentWatchAllItem;

/// This builder prevents observations from happening within the builder. It
/// should be used in conjunction with AnthemModelBase.observeAllChanges().
///
/// For example:
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   someModelItem.observeAllChanges();
///
///   return blockObservationBuilder(
///     modelItems: [someModelItem],
///     builder: () {
///       return Text(someModelItem.someObservableValue.toString());
///     },
///   );
/// }
/// ```
Widget? blockObservationBuilder({
  required List<AnthemModelBase> modelItems,
  required Widget? Function() builder,
}) {
  for (final modelItem in modelItems) {
    modelItem.observationBlockDepth++;
    incrementBlockObservationBuilderDepth();
  }

  final result = builder();

  for (final modelItem in modelItems) {
    modelItem.observationBlockDepth--;
    decrementBlockObservationBuilderDepth();
  }

  return result;
}

/// Blocks observations from happening within the block. This should be used in
/// conjunction with AnthemModelBase.observeAllChanges().
///
/// For example:
///
/// ```dart
/// someModelItem.observeAllChanges();
///
/// blockObservation(
///   modelItems: [someModelItem],
///   block: () {
///     print(someModelItem.someObservableValue.toString());
///   },
/// );
/// ```
void blockObservation({
  required List<AnthemModelBase> modelItems,
  required void Function() block,
}) {
  for (final modelItem in modelItems) {
    modelItem.observationBlockDepth++;
    incrementBlockObservationBuilderDepth();
  }

  block();

  for (final modelItem in modelItems) {
    modelItem.observationBlockDepth--;
    decrementBlockObservationBuilderDepth();
  }
}
