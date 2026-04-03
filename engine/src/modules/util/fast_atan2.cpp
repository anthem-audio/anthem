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

  This file adapts the atan2approx implementation from Dmytro Mishkin's
  fast_atan2 project. The original notice follows:

  Copyright (c) 2013, Dmytro Mishkin
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
      * Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.
      * Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.
      * Neither the name of Dmytro Mishkin nor the names of his contributors
        may be used to endorse or promote products derived from this software
        without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY DMYTRO MISHKIN ''AS IS'' AND ANY
  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL DMYTRO MISHKIN BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "fast_atan2.h"

#include <cmath>

namespace {
constexpr double kPi = 3.14159265358979323846;
constexpr double kPi4Plus0273 = kPi / 4.0 + 0.273;
constexpr double kPi2 = kPi / 2.0;
} // namespace

float fastAtan2(float y, float x) {
  const double absy = std::fabs(static_cast<double>(y));
  const double absx = std::fabs(static_cast<double>(x));
  const int octant = (static_cast<int>(x < 0.0f) << 2) | (static_cast<int>(y < 0.0f) << 1) |
                     static_cast<int>(absx <= absy);

  switch (octant) {
    case 0: {
      if (x == 0.0f && y == 0.0f) {
        return 0.0f;
      }

      const double val = absy / absx;
      return static_cast<float>((kPi4Plus0273 - 0.273 * val) * val);
    }

    case 1: {
      if (x == 0.0f && y == 0.0f) {
        return 0.0f;
      }

      const double val = absx / absy;
      return static_cast<float>(kPi2 - (kPi4Plus0273 - 0.273 * val) * val);
    }

    case 2: {
      const double val = absy / absx;
      return static_cast<float>(-(kPi4Plus0273 - 0.273 * val) * val);
    }

    case 3: {
      const double val = absx / absy;
      return static_cast<float>(-kPi2 + (kPi4Plus0273 - 0.273 * val) * val);
    }

    case 4: {
      const double val = absy / absx;
      return static_cast<float>(kPi - (kPi4Plus0273 - 0.273 * val) * val);
    }

    case 5: {
      const double val = absx / absy;
      return static_cast<float>(kPi2 + (kPi4Plus0273 - 0.273 * val) * val);
    }

    case 6: {
      const double val = absy / absx;
      return static_cast<float>(-kPi + (kPi4Plus0273 - 0.273 * val) * val);
    }

    case 7: {
      const double val = absx / absy;
      return static_cast<float>(-kPi2 - (kPi4Plus0273 - 0.273 * val) * val);
    }

    default:
      return 0.0f;
  }
}
