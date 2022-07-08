/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

part of 'project_cubit.dart';

// Workaround for https://github.com/rrousselGit/freezed/issues/653
@Freezed(makeCollectionsUnmodifiable: false)
class ProjectState with _$ProjectState {
  factory ProjectState({
    required ID id,
    @Default(true) bool isProjectExplorerVisible,
    @Default(true) bool isPatternEditorVisible,
    @Default(true) bool isAutomationMatrixVisible,
    @Default(ProjectLayoutKind.arrange) ProjectLayoutKind layout,
    @Default(null) DetailViewKind? selectedDetailView,
    @Default(EditorKind.detail) EditorKind selectedEditor,
  }) = _ProjectState;
}

enum ProjectLayoutKind { arrange, edit, mix }

enum EditorKind {
  detail,
  automation,
  channelRack,
  mixer,
}



/// Used to describe which detail view is active in the project sidebar, if any
abstract class DetailViewKind {}

class PatternDetailViewKind extends DetailViewKind {
  ID patternID;
  PatternDetailViewKind(this.patternID);
}

class ArrangementDetailViewKind extends DetailViewKind {
  ID arrangementID;
  ArrangementDetailViewKind(this.arrangementID);
}
