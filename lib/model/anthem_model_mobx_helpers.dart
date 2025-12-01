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

import 'package:anthem_codegen/include.dart';
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
T blockObservation<T>({
  required List<AnthemModelBase> modelItems,
  required T Function() block,
}) {
  for (final modelItem in modelItems) {
    beginObservationBlockFor(modelItem);
  }

  final result = block();

  for (final modelItem in modelItems) {
    endObservationBlockFor(modelItem);
  }

  return result;
}

/// Begins an observation block for the given model item.
///
/// This is one half of [blockObservation]. See that function for more details.
///
/// [endObservationBlockFor] must be called later for the same model item.
///
/// [beginObservationBlockFor] and [endObservationBlockFor] calls can be used
/// instead of [blockObservation] if it is more convenient.
void beginObservationBlockFor(AnthemModelBase modelItem) {
  modelItem.observationBlockDepth++;
  incrementBlockObservationBuilderDepth();
}

/// Ends an observation block for the given model item.
///
/// This is one half of [blockObservation]. See that function for more details.
///
/// [beginObservationBlockFor] must have been called previously for the same
/// model item.
///
/// [beginObservationBlockFor] and [endObservationBlockFor] calls can be used
/// instead of [blockObservation] if it is more convenient.
void endObservationBlockFor(AnthemModelBase modelItem) {
  assert(modelItem.observationBlockDepth > 0);
  modelItem.observationBlockDepth--;
  decrementBlockObservationBuilderDepth();
}
