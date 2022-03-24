part of 'pattern_picker_cubit.dart';

@freezed
class PatternPickerState with _$PatternPickerState {
  factory PatternPickerState({
    required int projectID,
    required List<int> patternIDs,
  }) = _PatternPickerState;
}
