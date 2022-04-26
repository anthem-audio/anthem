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

part of 'state_changes.dart';

/*
 * Base classes
 */

abstract class ArrangementStateChange extends ProjectStateChange {
  ID arrangementID;

  ArrangementStateChange({required ID projectID, required this.arrangementID})
      : super(projectID: projectID);
}

/*
 * State changes
 */

class ClipAdded extends ArrangementStateChange {
  ClipAdded({
    required ID projectID,
    required ID arrangementID,
  }) : super(
          projectID: projectID,
          arrangementID: arrangementID,
        );
}

class ClipDeleted extends ArrangementStateChange {
  ClipDeleted({
    required ID projectID,
    required ID arrangementID,
  }) : super(
          projectID: projectID,
          arrangementID: arrangementID,
        );
}

class ArrangementAdded extends ArrangementStateChange {
  ArrangementAdded({
    required ID projectID,
    required ID arrangementID,
  }) : super(
          projectID: projectID,
          arrangementID: arrangementID,
        );
}

class ArrangementDeleted extends ArrangementStateChange {
  ArrangementDeleted({
    required ID projectID,
    required ID arrangementID,
  }) : super(
          projectID: projectID,
          arrangementID: arrangementID,
        );
}
