part of 'pattern_picker_cubit.dart';

@freezed
class PatternPickerState with _$PatternPickerState {
  factory PatternPickerState({
    required ID projectID,
    required List<ID> patternIDs,
    required double patternHeight,
  }) = _PatternPickerState;
}
