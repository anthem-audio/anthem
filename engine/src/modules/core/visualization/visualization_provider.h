/*
  Copyright (C) 2025 Joshua Wade

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

#include <vector>

// This is an abstract interface for visualization data providers. It is used by the
// VisualizationBroker to query data from various sources in the engine.
class VisualizationDataProvider {
public:
  virtual ~VisualizationDataProvider() = default;

  // Get the most recent data for this provider, if any
  virtual std::vector<double> getData() = 0;
};
