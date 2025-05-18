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

part of 'package:anthem/engine_api/engine.dart';

class SequencerApi {
  final Engine _engine;

  SequencerApi(this._engine);

  /// Tells the engine to compile the given arrangement.
  ///
  /// If [channelsToRebuild] is specified, only the given channels will be
  /// rebuilt. Otherwise, all channels will be rebuilt.
  ///
  /// If [invalidationRanges] is specified, these are the ranges of the sequence
  /// that are no longer "valid". Valid in this context means that the data within
  /// this range is changed and can no longer be relied on for playback. For
  /// example, if an instrument has received a note on event and the playhead is
  /// within one of these ranges, the instrument is not guaranteed to receive a
  /// matching note off event.
  ///
  /// If [invalidationRanges] is specified, [channelsToRebuild] must also be
  /// specified, and vice versa.
  void compileArrangement(
    Id arrangementId, {
    List<String>? channelsToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {
    // if ((channelsToRebuild == null) != (invalidationRanges == null)) {
    //   throw ArgumentError(
    //     'channelsToRebuild and invalidationRanges must both be specified or both be null',
    //   );
    // }

    final request = CompileSequenceRequest.arrangement(
      id: _engine._getRequestId(),
      arrangementId: arrangementId.toString(),
      channelsToRebuild: channelsToRebuild,
      invalidationRanges: invalidationRanges,
    );

    _engine._requestNoReply(request);
  }

  /// Tells the engine to compile the given pattern.
  ///
  /// If [channelsToRebuild] is specified, only the given channels will be
  /// rebuilt. Otherwise, all channels will be rebuilt.
  ///
  /// If [invalidationRanges] is specified, these are the ranges of the sequence
  /// that are no longer "valid". Valid in this context means that the data within
  /// this range is changed and can no longer be relied on for playback. For
  /// example, if an instrument has received a note on event and the playhead is
  /// within one of these ranges, the instrument is not guaranteed to receive a
  /// matching note off event.
  ///
  /// If [invalidationRanges] is specified, [channelsToRebuild] must also be
  /// specified, and vice versa.
  void compilePattern(
    Id patternId, {
    List<String>? channelsToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {
    // if ((channelsToRebuild == null) != (invalidationRanges == null)) {
    //   throw ArgumentError(
    //     'channelsToRebuild and invalidationRanges must both be specified or both be null',
    //   );
    // }

    final request = CompileSequenceRequest.pattern(
      id: _engine._getRequestId(),
      patternId: patternId.toString(),
      channelsToRebuild: channelsToRebuild,
    );

    _engine._requestNoReply(request);
  }

  /// Cleans up the given channel from the sequencer.
  ///
  /// This method allows us to remove a channel from the sequencer without
  /// needing to rebuild all of the sequences.
  ///
  /// Normally when we update sequences, we update only one or maybe a few
  /// channels at a time. However, when a channel is removed from the project
  /// model, we need a way to remove that channel from all of the compiled
  /// sequences in the engine - otherwise, we would need to rebuild each
  /// sequence from scratch to remove that channel.
  void cleanUpChannel(String channelId) {
    final request = RemoveChannelRequest(
      id: _engine._getRequestId(),
      channelId: channelId,
    );

    _engine._requestNoReply(request);
  }

  /// Starts the transport.
  ///
  /// This is not yet fine-grained to specific sequences, and will simply start
  /// playing first arrangement. This is temporary and will need to be refined.
  void play() {
    final request = PlayRequest(id: _engine._getRequestId());
    _engine._requestNoReply(request);
  }

  /// Stops the transport.
  void stop() {
    final request = StopRequest(id: _engine._getRequestId());
    _engine._requestNoReply(request);
  }
}
