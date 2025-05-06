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

#include "global_visualization_sources.h"

std::vector<double> CpuVisualizationProvider::getData() {
  auto result = cpuBurden.load();

  overwriteNextUpdate.store(true);

  return { result };
}

// Every time we read, we want the max value since the last time we read. When
// writing below, if overwriteNextUpdate is true, we will overwrite the value
// regardless of the value. Otherwise, we will only overwrite the value if the
// new value is greater than the current value.
void CpuVisualizationProvider::updateCpuBurden(double newCpuBurden) {
  if (overwriteNextUpdate.load()) {
    overwriteNextUpdate.store(false);
    cpuBurden.store(newCpuBurden);
    return;
  } else {
    auto currentCpuBurden = cpuBurden.load();
    if (newCpuBurden > currentCpuBurden) {
      cpuBurden.store(newCpuBurden);
    }
  }
}

GlobalVisualizationSources::GlobalVisualizationSources() {
  // Initialize the CPU burden provider
  cpuBurdenProvider = std::make_shared<CpuVisualizationProvider>();

  // Register global sources with the visualization broker
  VisualizationBroker::getInstance().registerDataProvider("cpu", cpuBurdenProvider);
}
