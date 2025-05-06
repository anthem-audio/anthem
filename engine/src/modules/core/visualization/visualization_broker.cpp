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

#include "visualization_broker.h"

VisualizationBroker::VisualizationBroker() {
  std::cout << "VisualizationBroker CTOR." << std::endl;
  this->updateIntervalMs = 15.0;
  this->startTimerHz(static_cast<int>(1000.0 / this->updateIntervalMs));
}

void VisualizationBroker::setSubscriptions(
  const std::vector<std::string>& subscriptions
) {
  std::cout << "Setting subscriptions: ";
  for (const auto& subscription : subscriptions) {
    std::cout << subscription << ", ";
  }
  std::cout << std::endl;

  this->subscriptions = subscriptions;
}

void VisualizationBroker::setUpdateInterval(
  double updateIntervalMs
) {
  std::cout << "Setting update interval to: " << updateIntervalMs << " ms" << std::endl;

  this->updateIntervalMs = updateIntervalMs;

  this->stopTimer();
  this->startTimerHz(static_cast<int>(1000.0 / this->updateIntervalMs));
}

void VisualizationBroker::timerCallback() {
  // Iterate over all subscriptions and query the data providers for updates
  for (const auto& subscription : this->subscriptions) {
    auto it = this->dataProviders.find(subscription);
    if (it != this->dataProviders.end()) {
      auto data = it->second->getData();
      std::cout << "Data for " << subscription << ": ";
      for (const auto& value : data) {
        std::cout << value << ", ";
      }
      std::cout << std::endl;
    }
  }
}
