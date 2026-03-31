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

#pragma once

// Declaration for Anthem's adapted copy of Dmytro Mishkin's BSD-3-Clause
// fast_atan2 implementation. See fast_atan2.cpp for the original notice.
//
// Approximated function taken from:
// Rajan, S.; Wang, S.; Inkol, R. & Joyal, A.
// Efficient approximations for the arctangent function
// Signal Processing Magazine, IEEE, 2006, 23, 108-111
float fastAtan2(float y, float x);
