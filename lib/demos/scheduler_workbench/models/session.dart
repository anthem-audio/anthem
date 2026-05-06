/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:mobx/mobx.dart';

import 'track.dart';

part 'session.g.dart';

// ignore: library_private_types_in_public_api
class SessionModel = _SessionModel with _$SessionModel;

abstract class _SessionModel with Store {
  @observable
  ObservableList<TrackModel> tracks = ObservableList<TrackModel>();

  @observable
  ObservableList<int> sendNodeIds = ObservableList<int>();

  @observable
  int? masterNodeId;

  @action
  void replace({
    required Iterable<TrackModel> tracks,
    required Iterable<int> sendNodeIds,
    required int masterNodeId,
  }) {
    this.tracks = ObservableList.of(tracks);
    this.sendNodeIds = ObservableList.of(sendNodeIds);
    this.masterNodeId = masterNodeId;
  }
}
