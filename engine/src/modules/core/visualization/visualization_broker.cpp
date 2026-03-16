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

#include "visualization_broker.h"

#include "messages/messages.h"

#include "modules/core/anthem.h"

#include <utility>

VisualizationBroker::VisualizationBroker() {
  this->updateIntervalMs = 15.0;
  this->startTimerHz(static_cast<int>(1000.0 / this->updateIntervalMs));
}

void VisualizationBroker::setSubscriptions(
  const std::vector<std::string>& newSubscriptions
) {
  this->subscriptions = newSubscriptions;
}

void VisualizationBroker::setUpdateInterval(
  double newUpdateIntervalMs
) {
  this->updateIntervalMs = newUpdateIntervalMs;

  this->stopTimer();
  this->startTimerHz(static_cast<int>(1000.0 / this->updateIntervalMs));
}

void VisualizationBroker::timerCallback() {
  if (this->subscriptions.empty()) {
    return;
  }

  auto visualizationItems = std::make_shared<std::vector<std::shared_ptr<VisualizationItem>>>();

  // Iterate over all subscriptions and query the data providers for updates
  for (const auto& subscription : this->subscriptions) {
    auto it = this->dataProviders.find(subscription);
    if (it != this->dataProviders.end()) {
      std::optional<NumericVisualizationData> numericData = it->second->getNumericData();

      if (numericData.has_value() && !numericData.value().values.empty()) {
        auto numericBatch = std::move(numericData.value());

        if (numericBatch.sampleTimestamps.size() != numericBatch.values.size()) {
          jassertfalse;
          continue;
        }

        auto dataSharedPtr = std::make_shared<std::vector<double>>(std::move(numericBatch.values));
        auto sampleTimestampsSharedPtr = std::make_shared<std::vector<int64_t>>(std::move(numericBatch.sampleTimestamps));

        auto visualizationItem = std::make_shared<VisualizationItem>(
          VisualizationItem{
            .id = subscription,
            .values = rfl::make_field<"List<double>">(dataSharedPtr),
            .sampleTimestamps = sampleTimestampsSharedPtr,
          }
        );

        visualizationItems->push_back(visualizationItem);

        continue;
      }

      std::optional<IntegerVisualizationData> integerData = it->second->getIntegerData();

      if (integerData.has_value() && !integerData.value().values.empty()) {
        auto integerBatch = std::move(integerData.value());

        if (integerBatch.sampleTimestamps.size() != integerBatch.values.size()) {
          jassertfalse;
          continue;
        }

        auto dataSharedPtr = std::make_shared<std::vector<int64_t>>(std::move(integerBatch.values));
        auto sampleTimestampsSharedPtr = std::make_shared<std::vector<int64_t>>(std::move(integerBatch.sampleTimestamps));

        auto visualizationItem = std::make_shared<VisualizationItem>(
          VisualizationItem{
            .id = subscription,
            .values = rfl::make_field<"List<int>">(dataSharedPtr),
            .sampleTimestamps = sampleTimestampsSharedPtr,
          }
        );

        visualizationItems->push_back(visualizationItem);

        continue;
      }

      std::optional<StringVisualizationData> stringData = it->second->getStringData();

      if (stringData.has_value() && !stringData.value().values.empty()) {
        auto stringBatch = std::move(stringData.value());

        if (stringBatch.sampleTimestamps.size() != stringBatch.values.size()) {
          jassertfalse;
          continue;
        }

        auto dataSharedPtr = std::make_shared<std::vector<std::string>>(std::move(stringBatch.values));
        auto sampleTimestampsSharedPtr = std::make_shared<std::vector<int64_t>>(std::move(stringBatch.sampleTimestamps));

        auto visualizationItem = std::make_shared<VisualizationItem>(
          VisualizationItem{
            .id = subscription,
            .values = rfl::make_field<"List<String>">(dataSharedPtr),
            .sampleTimestamps = sampleTimestampsSharedPtr,
          }
        );

        visualizationItems->push_back(visualizationItem);

        continue;
      }
    }
  }

  if (visualizationItems->empty()) {
    return;
  }

  // Create a VisualizationUpdateEvent message and send it to the UI
  Response visualizationUpdate = VisualizationUpdateEvent {
    .items = visualizationItems,
    .responseBase = ResponseBase {
      // Usually, the response ID is the same as the ID of the request that was
      // sent to the engine. In this case, there was no request, so we set it to
      // -1.
      .id = -1,
    }
  };

  auto responseText = rfl::json::write(visualizationUpdate);
  Anthem::getInstance().comms.send(responseText);
}

void VisualizationBroker::dispose() {
  this->stopTimer();
  this->dataProviders.clear();
  this->subscriptions.clear();
}
