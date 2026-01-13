/*
  Copyright (C) 2026 Joshua Wade

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

/// Gets a single string attribute value from multiple items.
///
/// For example, if this is for clip name, attributeValues will be all selected
/// clips. If one clip is selected, this will give back that clip's name. If
/// multiple are selected, this will give back one name if they all have the
/// same name, and empty string otherwise.
String getStringAttributeValue(Iterable<String> attributeValues) {
  if (attributeValues.isEmpty) return '';

  final firstValue = attributeValues.first;
  var allEqual = true;

  for (final value in attributeValues.skip(1)) {
    if (value != firstValue) {
      allEqual = false;
      break;
    }
  }

  if (allEqual) {
    return firstValue;
  } else {
    return '';
  }
}
