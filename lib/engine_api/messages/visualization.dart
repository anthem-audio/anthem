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

part of 'messages.dart';

/// Provides the engine with the visualization items that it is currently
/// interested in.
class SetVisualizationSubscriptionsRequest extends Request {
  /// The list of visualization items that the engine is interested in.
  ///
  /// This is a list of strings that are the IDs of the visualization items. The
  /// engine will only send updates for these items.
  ///
  /// This replaces any existing subscriptions.
  List<String> subscriptions;

  SetVisualizationSubscriptionsRequest.uninitialized()
      : subscriptions = [];

  SetVisualizationSubscriptionsRequest({required int id, required this.subscriptions}) {
    super.id = id;
  }
}

/// Represents a value that the engine is sending updates for.
///
/// Some items only ever have one value, while others can have multiple values,
/// depending on what they are representing.
@AnthemModel(serializable: true, generateCpp: true)
class VisualizationItem extends _VisualizationItem with _$VisualizationItemAnthemModelMixin {
  VisualizationItem.uninitialized() : super(id: '', values: []);

  VisualizationItem({required super.id, required super.values});

  factory VisualizationItem.fromJson(Map<String, dynamic> json) =>
      _$VisualizationItemAnthemModelMixin.fromJson(json);
}

abstract class _VisualizationItem {
  String id;
  List<double> values;

  _VisualizationItem({required this.id, required this.values});
}

/// An unsolicited response that gives back visualization data.
class VisualizationUpdate extends Response {
  /// The list of visualization items that the engine is sending updates for.
  ///
  /// This is a list of strings that are the IDs of the visualization items. The
  /// engine will only send updates for these items.
  List<VisualizationItem> items;

  VisualizationUpdate.uninitialized() : items = [];

  VisualizationUpdate({required int id, required this.items}) {
    super.id = id;
  }
}
