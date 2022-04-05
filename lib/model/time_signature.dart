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

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'time_signature.g.dart';

@JsonSerializable()
class TimeSignatureModel {
  int numerator;
  int denominator;

  TimeSignatureModel(
    this.numerator,
    this.denominator,
  );

  factory TimeSignatureModel.fromJson(Map<String, dynamic> json) =>
      _$TimeSignatureModelFromJson(json);

  Map<String, dynamic> toJson() => _$TimeSignatureModelToJson(this);

  @override
  String toString() => json.encode(toJson());
}

@JsonSerializable()
class TimeSignatureChangeModel {
  TimeSignatureModel timeSignature;
  int offset;

  TimeSignatureChangeModel({
    required this.timeSignature,
    required this.offset,
  });

  factory TimeSignatureChangeModel.fromJson(Map<String, dynamic> json) =>
      _$TimeSignatureChangeModelFromJson(json);

  Map<String, dynamic> toJson() => _$TimeSignatureChangeModelToJson(this);

  @override
  String toString() => json.encode(toJson());
}
