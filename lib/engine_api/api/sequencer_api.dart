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
  /// If [tracksToRebuild] is specified, only the given tracks will be
  /// rebuilt. Otherwise, all tracks will be rebuilt.
  ///
  /// If [invalidationRanges] is specified, these are the ranges of the sequence
  /// that are no longer "valid". Valid in this context means that the data within
  /// this range is changed and can no longer be relied on for playback. For
  /// example, if an instrument has received a note on event and the playhead is
  /// within one of these ranges, the instrument is not guaranteed to receive a
  /// matching note off event.
  ///
  /// If [invalidationRanges] is specified, [tracksToRebuild] must also be
  /// specified, and vice versa.
  void compileArrangement(
    Id arrangementId, {
    List<Id>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {
    final request = CompileSequenceRequest.arrangement(
      id: _engine._getRequestId(),
      arrangementId: arrangementId,
      tracksToRebuild: tracksToRebuild,
      invalidationRanges: invalidationRanges,
    );

    _engine._requestNoReply(
      request,
      startupBehavior: StartupSendBehavior.queueDuringStartup,
    );
  }

  /// Tells the engine to compile the given pattern.
  ///
  /// If [tracksToRebuild] is specified, only the given tracks will be
  /// rebuilt. Otherwise, all tracks will be rebuilt.
  ///
  /// If [invalidationRanges] is specified, these are the ranges of the sequence
  /// that are no longer "valid". Valid in this context means that the data within
  /// this range is changed and can no longer be relied on for playback. For
  /// example, if an instrument has received a note on event and the playhead is
  /// within one of these ranges, the instrument is not guaranteed to receive a
  /// matching note off event.
  ///
  /// If [invalidationRanges] is specified, [tracksToRebuild] must also be
  /// specified, and vice versa.
  void compilePattern(
    Id patternId, {
    List<Id>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {
    final request = CompileSequenceRequest.pattern(
      id: _engine._getRequestId(),
      patternId: patternId,
      tracksToRebuild: tracksToRebuild,
      invalidationRanges: invalidationRanges,
    );

    _engine._requestNoReply(
      request,
      startupBehavior: StartupSendBehavior.queueDuringStartup,
    );
  }

  /// Cleans up the given track from the sequencer.
  ///
  /// This method allows us to remove a track from the sequencer without
  /// needing to rebuild all of the sequences.
  ///
  /// Normally when we update sequences, we update only one or maybe a few
  /// tracks at a time. However, when a track is removed from the project
  /// model, we need a way to remove that track from all of the compiled
  /// sequences in the engine - otherwise, we would need to rebuild each
  /// sequence from scratch to remove that track.
  void cleanUpTrack(Id trackId) {
    final request = RemoveTrackRequest(
      id: _engine._getRequestId(),
      trackId: trackId,
    );

    _engine._requestNoReply(
      request,
      startupBehavior: StartupSendBehavior.queueDuringStartup,
    );
  }

  /// Jumps the playhead to the given timestamp.
  void jumpPlayheadTo(double offset) {
    final request = PlayheadJumpRequest(
      id: _engine._getRequestId(),
      offset: offset,
    );

    _engine._requestNoReply(request);
  }

  /// Sends the new loop points to the audio thread for the given sequence ID,
  /// if the active sequence ID matches the given sequence ID.
  void updateLoopPoints(Id sequenceId) {
    final request = LoopPointsChangedRequest(
      id: _engine._getRequestId(),
      sequenceId: sequenceId,
    );

    _engine._requestNoReply(request);
  }
}
