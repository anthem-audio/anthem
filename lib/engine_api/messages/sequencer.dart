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

@AnthemModel(serializable: true, generateCpp: true)
class InvalidationRange extends _InvalidationRange
    with _$InvalidationRangeAnthemModelMixin {
  InvalidationRange.uninitialized() : super(start: 0, end: 0);

  InvalidationRange({required super.start, required super.end});

  factory InvalidationRange.fromJson(Map<String, dynamic> json) =>
      _$InvalidationRangeAnthemModelMixin.fromJson(json);
}

abstract class _InvalidationRange {
  int start;
  int end;

  _InvalidationRange({required this.start, required this.end});
}

/// A request to compile either a pattern or an arrangement.
class CompileSequenceRequest extends Request {
  /// The channel IDs to rebuild.
  ///
  /// If unspecified, all channels will be rebuilt.
  List<String>? channelsToRebuild;

  /// If specified, these are the ranges of the sequence that are no longer
  /// "valid".
  ///
  /// Valid in this context means that the data within this range is changed and
  /// can no longer be relied on for playback. For example, if an instrument has
  /// received a note on event and the playhead is within one of these ranges,
  /// the instrument is not guaranteed to receive a matching note off event.
  ///
  /// The audio thread in the engine is expected to honor these ranges. If the
  /// playhead is within one of these ranges when the audio thread picks up the
  /// updated sequence data, it should send "release all notes" events (or
  /// equivalent) to all channels that were rebuilt.
  ///
  /// This should not be defined unless [channelsToRebuild] is also defined.
  List<InvalidationRange>? invalidationRanges;

  /// The pattern ID to compile.
  ///
  /// Either this or [arrangementId] must be specified.
  String? patternId;

  /// The arrangement ID to compile.
  ///
  /// Either this or [patternId] must be specified.
  String? arrangementId;

  CompileSequenceRequest.uninitialized();

  /// Creates a request to compile a pattern.
  CompileSequenceRequest.pattern({
    required int id,
    required this.patternId,
    this.channelsToRebuild,
    this.invalidationRanges,
  }) {
    super.id = id;
  }

  /// Creates a request to compile an arrangement.
  CompileSequenceRequest.arrangement({
    required int id,
    required this.arrangementId,
    this.channelsToRebuild,
    this.invalidationRanges,
  }) {
    super.id = id;
  }
}

/// A request to clean up the given channel from the sequencer.
///
/// This allows us to release memory from the compiled sequence data without
/// rebuilding every sequence.
class RemoveChannelRequest extends Request {
  /// The channel ID to remove.
  String channelId;

  RemoveChannelRequest.uninitialized() : channelId = '';

  RemoveChannelRequest({required int id, required this.channelId}) {
    super.id = id;
  }
}

/// Jumps the location of the playhead to the given offset.
class PlayheadJumpRequest extends Request {
  /// The offset to jump to
  double offset;

  PlayheadJumpRequest.uninitialized() : offset = 0;

  PlayheadJumpRequest({required int id, required this.offset}) {
    super.id = id;
  }
}

/// Notifies the engine that loop points have changed for a given sequence.
class LoopPointsChangedRequest extends Request {
  /// The sequence ID for which the loop points have changed.
  ///
  /// This will be either a pattern ID or an arrangement ID.
  String sequenceId;

  LoopPointsChangedRequest.uninitialized() : sequenceId = '';

  LoopPointsChangedRequest({required int id, required this.sequenceId}) {
    super.id = id;
  }
}
