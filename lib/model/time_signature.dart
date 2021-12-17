/*
  Copyright (C) 2021 Joshua Wade

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

class TimeSignatureModel {
  int numerator;
  int denominator;

  TimeSignatureModel(
    this.numerator,
    this.denominator,
  );
}

class TimeSignatureChangeModel {
  TimeSignatureModel timeSignature;
  int offset;

  TimeSignatureChangeModel({
    required this.timeSignature,
    required this.offset,
  });
}
