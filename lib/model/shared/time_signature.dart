/*
  Copyright (C) 2021 - 2024 Joshua Wade

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
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import '../shared/hydratable.dart';

part 'time_signature.g.dart';

@AnthemModel.all()
class TimeSignatureModel extends _TimeSignatureModel
    with _$TimeSignatureModel, _$TimeSignatureModelAnthemModelMixin {
  TimeSignatureModel(super.numerator, super.denominator);

  TimeSignatureModel.uninitialized() : super(4, 4);

  factory TimeSignatureModel.fromJson(Map<String, dynamic> json) =>
      _$TimeSignatureModelAnthemModelMixin.fromJson(json);
}

abstract class _TimeSignatureModel extends Hydratable
    with Store, AnthemModelBase {
  @anthemObservable
  int numerator;

  @anthemObservable
  int denominator;

  _TimeSignatureModel(
    this.numerator,
    this.denominator,
  ) : super() {
    (this as _$TimeSignatureModelAnthemModelMixin).init();
    isHydrated = true;
  }

  String toDisplayString() => '$numerator/$denominator';
}

@AnthemModel.all()
class TimeSignatureChangeModel extends _TimeSignatureChangeModel
    with
        _$TimeSignatureChangeModel,
        _$TimeSignatureChangeModelAnthemModelMixin {
  TimeSignatureChangeModel({
    super.id,
    required super.timeSignature,
    required super.offset,
  });

  TimeSignatureChangeModel.uninitialized()
      : super(
          id: '',
          timeSignature: TimeSignatureModel(4, 4),
          offset: 0,
        );

  factory TimeSignatureChangeModel.fromJson(Map<String, dynamic> json) =>
      _$TimeSignatureChangeModelAnthemModelMixin.fromJson(json);
}

abstract class _TimeSignatureChangeModel extends Hydratable
    with Store, AnthemModelBase {
  ID id = '';

  @anthemObservable
  TimeSignatureModel timeSignature;

  @anthemObservable
  int offset;

  _TimeSignatureChangeModel({
    ID? id,
    required this.timeSignature,
    required this.offset,
  }) : super() {
    this.id = id ?? getID();

    (this as _$TimeSignatureChangeModelAnthemModelMixin).init();
    isHydrated = true;
  }
}
