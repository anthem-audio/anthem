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

import 'package:anthem/model/shared/time_signature.dart';
import 'package:mobx/mobx.dart';

part 'types.g.dart';

//
// Time-related types
//

// ignore: library_private_types_in_public_api
class TimeRange = _TimeRange with _$TimeRange;

abstract class _TimeRange with Store {
  _TimeRange(this.start, this.end);

  @observable
  double start;

  @observable
  double end;

  double get width => end - start;
}

// I don't remember how this works lol
class Division {
  Division({required this.multiplier, required this.divisor});

  int multiplier;
  int divisor;

  Time getSizeInTicks(Time ticksPerQuarter, TimeSignatureModel? timeSignature) {
    return ((ticksPerQuarter * 4) ~/ (timeSignature?.denominator ?? 4)) *
        multiplier ~/
        divisor;
  }
}

sealed class Snap {}

class BarSnap extends Snap {}

class DivisionSnap extends Snap {
  DivisionSnap({required this.division});
  Division division;
}

class AutoSnap extends Snap {}

typedef Time = int;

//
// Misc
//

enum EditorTool { pencil, eraser, select, cut }
