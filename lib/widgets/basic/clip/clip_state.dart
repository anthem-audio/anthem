/*
  Copyright (C) 2022 Joshua Wade

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

part of 'clip_cubit.dart';

@immutable
class ClipState {
  final PatternModel pattern;
  late int count = 0;

  ClipState({required this.pattern, int? count}) {
    if (count != null) this.count = count;
  }

  // Hack: Don't override == so that we can trigger a render on any pattern
  // state change

  ClipState copyWith({PatternModel? pattern}) {
    return ClipState(pattern: pattern ?? this.pattern);
  }
}
