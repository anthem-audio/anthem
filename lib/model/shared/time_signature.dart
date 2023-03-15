/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'time_signature.g.dart';

@JsonSerializable()
class TimeSignatureModel extends _TimeSignatureModel with _$TimeSignatureModel {
  TimeSignatureModel(int numerator, int denominator)
      : super(numerator, denominator);

  factory TimeSignatureModel.fromJson(Map<String, dynamic> json) =>
      _$TimeSignatureModelFromJson(json);
}

abstract class _TimeSignatureModel with Store {
  @observable
  int numerator;

  @observable
  int denominator;

  _TimeSignatureModel(
    this.numerator,
    this.denominator,
  );

  Map<String, dynamic> toJson() =>
      _$TimeSignatureModelToJson(this as TimeSignatureModel);

  String toDisplayString() => '$numerator/$denominator';
}

@JsonSerializable()
class TimeSignatureChangeModel extends _TimeSignatureChangeModel
    with _$TimeSignatureChangeModel {
  TimeSignatureChangeModel({
    ID? id,
    required TimeSignatureModel timeSignature,
    required int offset,
  }) : super(
          id: id,
          timeSignature: timeSignature,
          offset: offset,
        );

  factory TimeSignatureChangeModel.fromJson(Map<String, dynamic> json) =>
      _$TimeSignatureChangeModelFromJson(json);
}

abstract class _TimeSignatureChangeModel with Store {
  ID id = '';

  @observable
  TimeSignatureModel timeSignature;

  @observable
  int offset;

  _TimeSignatureChangeModel({
    ID? id,
    required this.timeSignature,
    required this.offset,
  }) {
    this.id = id ?? getID();
  }

  Map<String, dynamic> toJson() =>
      _$TimeSignatureChangeModelToJson(this as TimeSignatureChangeModel);
}
