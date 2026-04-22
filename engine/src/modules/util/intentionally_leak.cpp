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

#include "intentionally_leak.h"

#include <juce_core/juce_core.h>

// Queue overflow on these paths is treated as a debug-time bug. In release
// builds we still avoid non-real-time-safe cleanup by intentionally leaking.
// NOLINTBEGIN(clang-analyzer-cplusplus.NewDeleteLeaks)
namespace anthem {

void intentionallyLeak(void* ptr) {
  jassertfalse;
  juce::ignoreUnused(ptr);
}

} // namespace anthem
// NOLINTEND(clang-analyzer-cplusplus.NewDeleteLeaks)
