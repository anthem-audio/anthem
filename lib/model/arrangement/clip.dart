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

import 'package:anthem/helpers/get_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'clip.g.dart';

@JsonSerializable()
class ClipModel {
  int clipID = getID();
  TimeViewModel? timeView; // If null, we snap to content
  int patternID;
  int trackID;
  int offset;

  ClipModel({
    this.timeView,
    required this.patternID,
    required this.trackID,
    required this.offset,
  });

  factory ClipModel.fromJson(Map<String, dynamic> json) =>
      _$ClipModelFromJson(json);

  Map<String, dynamic> toJson() => _$ClipModelToJson(this);
}

@JsonSerializable()
class TimeViewModel {
  int start;
  int end;

  TimeViewModel({required this.start, required this.end});

  factory TimeViewModel.fromJson(Map<String, dynamic> json) =>
      _$TimeViewModelFromJson(json);

  Map<String, dynamic> toJson() => _$TimeViewModelToJson(this);

  int get width {
    return end - start;
  }
}
