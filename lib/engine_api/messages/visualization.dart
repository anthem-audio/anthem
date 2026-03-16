/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

  SetVisualizationSubscriptionsRequest.uninitialized() : subscriptions = [];

  SetVisualizationSubscriptionsRequest({
    required int id,
    required this.subscriptions,
  }) {
    super.id = id;
  }
}

/// Sets the preferred update interval for visualization items.
class SetVisualizationUpdateIntervalRequest extends Request {
  /// The preferred update interval for visualization items.
  double intervalMilliseconds;

  SetVisualizationUpdateIntervalRequest.uninitialized()
    : intervalMilliseconds = 0.0;

  SetVisualizationUpdateIntervalRequest({
    required int id,
    required this.intervalMilliseconds,
  }) {
    super.id = id;
  }
}

/// Represents a value that the engine is sending updates for.
///
/// Some items only ever have one value, while others can have multiple values,
/// depending on what they are representing.
@AnthemModel(serializable: true, generateCpp: true)
class VisualizationItem extends _VisualizationItem
    with _$VisualizationItemAnthemModelMixin {
  VisualizationItem.uninitialized()
    : super(id: '', values: <double>[], sampleTimestamps: <int>[]);

  VisualizationItem({
    required super.id,
    required super.values,
    required List<int> sampleTimestamps,
  }) : super(
         sampleTimestamps: _validateSampleTimestamps(values, sampleTimestamps),
       );

  static List<int> _validateSampleTimestamps(
    Object values,
    List<int> sampleTimestamps,
  ) {
    final valueList = values as List;

    if (sampleTimestamps.length != valueList.length) {
      throw ArgumentError(
        'sampleTimestamps must have the same length as values. '
        'Got ${sampleTimestamps.length} timestamps for ${valueList.length} values.',
      );
    }

    return sampleTimestamps;
  }

  factory VisualizationItem.fromJson(Map<String, dynamic> json) =>
      _$VisualizationItemAnthemModelMixin.fromJson(json);
}

abstract class _VisualizationItem {
  String id;

  @Union([List<double>, List<int>, List<String>])
  Object values;

  /// Sample-domain timestamps for the values in this item.
  ///
  /// Each timestamp is in the engine's monotonic sample counter domain, and the
  /// length must match the number of entries in [values].
  List<int> sampleTimestamps;

  _VisualizationItem({
    required this.id,
    required this.values,
    required this.sampleTimestamps,
  });
}

/// An unsolicited response that gives back visualization data.
class VisualizationUpdateEvent extends Response {
  /// The list of visualization items that the engine is sending updates for.
  ///
  /// This is a list of strings that are the IDs of the visualization items. The
  /// engine will only send updates for these items.
  List<VisualizationItem> items;

  VisualizationUpdateEvent.uninitialized() : items = [];

  VisualizationUpdateEvent({required int id, required this.items}) {
    super.id = id;
  }
}
