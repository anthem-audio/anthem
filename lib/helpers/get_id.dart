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

import 'dart:math';

final _random = Random();

// ignore: non_constant_identifier_names
final _2_32 = pow(2, 32).floor();

// This should be roughly equivalent to how we generate IDs in Rust
int getID() {
  final time = DateTime.now().millisecondsSinceEpoch;

  // Dart is weird with its number ops. It has << and >>, but those only work
  // on numbers up to 0xFFFFFFFF (Dart has 64-bit integers). As of 2.14 Dart
  // also has >>> which works as you would expect, but for some reason it
  // doesn't have <<<. For this reason, we resort to multiplying by 2^32 here.

  // We're bit-shifting to the right here because we may need to serialize
  // this, and when outputting JSON, Dart cannot serialize integers as
  // unsigned.
  final random = (_random.nextInt(0xFFFFFFFE) * _2_32) >>> 2;

  return random + time;
}
