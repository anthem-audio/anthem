/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#include <format>
#include <string>

namespace anthem {

class TestConstants {
public:
  static std::string getEmptyProjectJson() {
    return R"(
{
  "sequence": {
    "ticksPerQuarter": 96,
    "beatsPerMinuteRaw": 12800,
    "arrangement": {
      "id": 1,
      "name": "Arrangement 1",
      "clips": {},
      "timeSignatureChanges": []
    },
    "tracks": {},
    "trackOrder": [],
    "defaultTimeSignature": {
      "numerator": 4,
      "denominator": 4
    },
    "patterns": {},
    "patternOrder": []
  },
  "processingGraph": {
    "nodes": {},
    "connections": {},
    "masterOutputNodeId": ""
  },
  "generators": {},
  "generatorOrder": [],
  "id": "projectId",
  "isSaved": false
}
)";
  }

  static std::string getEmptyPatternJson(std::string patternId) {
    std::ostringstream oss;
    oss << R"(
{
  "id": ")"
        << patternId << R"(",
  "name": "Pattern with ID )"
        << patternId << R"(",
  "notes": {},
  "automationLanes": {},
  "timeSignatureChanges": []
}
)";
    return oss.str();
  }
};

} // namespace anthem
