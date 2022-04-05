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

import 'package:anthem/model/time_signature.dart';
import 'package:flutter/foundation.dart';

import '../shared/helpers/types.dart';

enum KeyType { black, white }
enum NotchType { above, below, both }

KeyType getKeyType(int key) {
  switch (key % 12) {
    case 1:
    case 4:
    case 6:
    case 9:
    case 11:
      return KeyType.black;
    default:
      return KeyType.white;
  }
}

NotchType getNotchType(int key) {
  final keyTypeBelow = getKeyType(key - 1);
  final keyTypeAbove = getKeyType(key + 1);

  if (keyTypeAbove == KeyType.black && keyTypeBelow == KeyType.white) {
    return NotchType.above;
  } else if (keyTypeAbove == KeyType.white && keyTypeBelow == KeyType.black) {
    return NotchType.below;
  }

  return NotchType.both;
}

double keyValueToPixels({
  required double keyValue,
  required double keyValueAtTop,
  required double keyHeight,
}) {
  final keyOffsetFromTop = keyValueAtTop - keyValue;
  return keyOffsetFromTop * keyHeight;
}

double pixelsToKeyValue({
  required double pixelOffsetFromTop,
  required double keyValueAtTop,
  required double keyHeight,
}) {
  final keyOffsetFromTop = pixelOffsetFromTop / keyHeight;
  return keyValueAtTop - keyOffsetFromTop;
}
