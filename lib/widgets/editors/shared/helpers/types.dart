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

import 'package:flutter/foundation.dart';

import '../../../../model/time_signature.dart';

class TimeView with ChangeNotifier, DiagnosticableTreeMixin {
  TimeView(this._start, this._end);

  double get start => _start;
  double get end => _end;

  void setStart(double value) {
    _start = value;
    notifyListeners();
  }

  void setEnd(double value) {
    _end = value;
    notifyListeners();
  }

  double _start;
  double _end;
}

class Division {
  Division({
    required this.multiplier,
    required this.divisor,
  });

  int multiplier;
  int divisor;

  Time getSizeInTicks(Time ticksPerQuarter, TimeSignatureModel? timeSignature) {
    return ((ticksPerQuarter * 4) ~/ (timeSignature?.denominator ?? 4)) *
        multiplier ~/
        divisor;
  }
}

abstract class Snap {}

class BarSnap extends Snap {}

class DivisionSnap extends Snap {
  DivisionSnap({required this.division});
  Division division;
}

typedef Time = int;
