part of 'pattern_picker_cubit.dart';

// Workaround for https://github.com/rrousselGit/freezed/issues/653
@Freezed(makeCollectionsUnmodifiable: false)
class PatternPickerState with _$PatternPickerState {
  factory PatternPickerState({
    required ID projectID,
    required List<ID> patternIDs,
    required double patternHeight,
    @Default(PatternFilterKind.midi) PatternFilterKind filterType,
  }) = _PatternPickerState;
}

enum PatternFilterKind { midi, audio, automation }
