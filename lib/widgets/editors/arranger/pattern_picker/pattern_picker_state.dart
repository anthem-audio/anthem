part of 'pattern_picker_cubit.dart';

@immutable
class PatternPickerState {
  final int projectID;
  final List<PatternModel> patterns;

  const PatternPickerState({required this.projectID, required this.patterns});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatternPickerState && other.patterns == patterns;

  @override
  int get hashCode => patterns.hashCode;

  PatternPickerState copyWith({int? projectID, List<PatternModel>? patterns}) {
    return PatternPickerState(
      projectID: projectID ?? this.projectID,
      patterns: patterns ?? this.patterns,
    );
  }
}
