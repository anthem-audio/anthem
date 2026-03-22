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

part of 'package:anthem/engine_api/engine.dart';

/// Provides APIs for configuring engine-side visualization streams.
class VisualizationApi {
  final Engine _engine;

  VisualizationApi(this._engine);

  static const String playheadPositionKey = 'playhead_position';
  static const String playheadSequenceIdKey = 'playhead_sequence_id';
  static const String cpuKey = 'cpu';

  /// Sets the visualization streams that the engine should publish.
  void setSubscriptions(List<VisualizationSubscriptionSpec> subscriptions) {
    final request = SetVisualizationSubscriptionsRequest(
      id: _engine._getRequestId(),
      subscriptions: subscriptions,
    );

    _engine._requestNoReply(
      request,
      startupBehavior: StartupSendBehavior.queueDuringStartup,
    );
  }

  /// Sets how often the engine should publish visualization updates.
  void setUpdateInterval(double intervalMilliseconds) {
    final request = SetVisualizationUpdateIntervalRequest(
      id: _engine._getRequestId(),
      intervalMilliseconds: intervalMilliseconds,
    );

    _engine._requestNoReply(
      request,
      startupBehavior: StartupSendBehavior.queueDuringStartup,
    );
  }
}
