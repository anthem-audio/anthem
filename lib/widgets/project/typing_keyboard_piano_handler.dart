/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:flutter/services.dart';

/// List of keys and their corresponding MIDI note numbers
final _keySet = <LogicalKeyboardKey, int>{
  // Lower octave
  LogicalKeyboardKey.keyZ: 48,
  LogicalKeyboardKey.keyS: 49,
  LogicalKeyboardKey.keyX: 50,
  LogicalKeyboardKey.keyD: 51,
  LogicalKeyboardKey.keyC: 52,
  LogicalKeyboardKey.keyV: 53,
  LogicalKeyboardKey.keyG: 54,
  LogicalKeyboardKey.keyB: 55,
  LogicalKeyboardKey.keyH: 56,
  LogicalKeyboardKey.keyN: 57,
  LogicalKeyboardKey.keyJ: 58,
  LogicalKeyboardKey.keyM: 59,
  LogicalKeyboardKey.comma: 60,
  LogicalKeyboardKey.keyL: 61,
  LogicalKeyboardKey.period: 62,
  LogicalKeyboardKey.semicolon: 63,
  LogicalKeyboardKey.slash: 64,

  // Upper octave (60 is middle C)
  LogicalKeyboardKey.keyQ: 60,
  LogicalKeyboardKey.digit2: 61,
  LogicalKeyboardKey.keyW: 62,
  LogicalKeyboardKey.digit3: 63,
  LogicalKeyboardKey.keyE: 64,
  LogicalKeyboardKey.keyR: 65,
  LogicalKeyboardKey.digit5: 66,
  LogicalKeyboardKey.keyT: 67,
  LogicalKeyboardKey.digit6: 68,
  LogicalKeyboardKey.keyY: 69,
  LogicalKeyboardKey.digit7: 70,
  LogicalKeyboardKey.keyU: 71,
  LogicalKeyboardKey.keyI: 72,
  LogicalKeyboardKey.digit9: 73,
  LogicalKeyboardKey.keyO: 74,
  LogicalKeyboardKey.digit0: 75,
  LogicalKeyboardKey.keyP: 76,
  LogicalKeyboardKey.bracketLeft: 77,
  LogicalKeyboardKey.equal: 78,
  LogicalKeyboardKey.bracketRight: 79,
};

/// Returns true if a given key is part of the typing keyboard piano
bool isTypingPianoKey(LogicalKeyboardKey key) => _keySet.containsKey(key);
int? getMidiNoteFromKeyboardKey(LogicalKeyboardKey key) => _keySet[key];
