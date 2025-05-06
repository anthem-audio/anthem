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

#include <memory>
#include <unordered_map>
#include <vector>
#include <string>
#include "visualization_provider.h"
#include "juce_events/juce_events.h"

// This class coordinates visualization subscriptions.
//
// The engine sends bulk visualization updates to the UI on a timer. There are
// wide range of data streams that can be sent in this way, including:
//  - Metering data from audio streams
//  - Oscilloscope data from audio streams
//  - Live control values
//  - MIDI data
//  - Current transport position
//
// Any place in the engine can register a data provider with this class. This
// data provider is expected to provide, at any time:
//  - The current value, in the case of a single value
//  - The values since the last update, in the case of a stream of values
//
// The UI can then subscribe to any of these data providers. Whatever
// subscriptions are active will determine which data providers have their data
// queryed and sent to the UI.
class VisualizationBroker : private juce::Timer {
private:
  // Private constructor for singleton pattern
  VisualizationBroker();

  // Private destructor
  ~VisualizationBroker() = default;

  // Deleted copy constructor and assignment operator
  VisualizationBroker(const VisualizationBroker&) = delete;
  VisualizationBroker& operator=(const VisualizationBroker&) = delete;

  // Deleted move constructor and assignment operator
  VisualizationBroker(VisualizationBroker&&) = delete;
  VisualizationBroker& operator=(VisualizationBroker&&) = delete;

  std::unordered_map<std::string, std::shared_ptr<VisualizationDataProvider>> dataProviders;
  std::vector<std::string> subscriptions;

  // The interval at which the visualization broker updates the UI, in
  // milliseconds
  //
  // Defaults to just faster than 60 FPS (16.67ms). If the UI has a faster
  // refresh rate, this will be set to a lower value.
  double updateIntervalMs;

  void timerCallback() override;

public:
  static VisualizationBroker& getInstance() {
    static VisualizationBroker instance;
    return instance;
  }

  void setSubscriptions(const std::vector<std::string>& newSubscriptions);
  void setUpdateInterval(double updateIntervalMs);
  void registerDataProvider(const std::string& name, std::shared_ptr<VisualizationDataProvider> provider) {
    dataProviders[name] = provider;
  }
  void unregisterDataProvider(const std::string& name) {
    dataProviders.erase(name);
  }
};
