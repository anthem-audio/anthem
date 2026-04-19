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

#include <type_traits>
#include <utility>

namespace {
template <typename T> using RemoveCvRef = std::remove_cv_t<std::remove_reference_t<T>>;
}

VisualizationBroker::VisualizationBroker() {
  this->updateIntervalMs = 15.0;
  this->startTimerHz(static_cast<int>(1000.0 / this->updateIntervalMs));
}

void VisualizationBroker::setSubscriptions(
    const std::vector<std::shared_ptr<VisualizationSubscriptionSpec>>& newSubscriptions) {
  this->subscriptions = newSubscriptions;
}

void VisualizationBroker::setUpdateInterval(double newUpdateIntervalMs) {
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
    auto it = this->dataProviders.find(subscription->id);
    if (it != this->dataProviders.end()) {
      const auto providerValueType = it->second->getValueType();
      if (providerValueType != subscription->valueType) {
        jassertfalse;
        continue;
      }

      auto data = it->second->getData();
      if (!data.has_value()) {
        continue;
      }

      std::visit(
          [&](auto&& batchValue) {
            using Batch = RemoveCvRef<decltype(batchValue)>;

            auto batch = std::forward<decltype(batchValue)>(batchValue);
            if (batch.values.empty()) {
              return;
            }

            if (batch.sampleTimestamps.size() != batch.values.size()) {
              jassertfalse;
              return;
            }

            auto sampleTimestampsSharedPtr =
                std::make_shared<std::vector<int64_t>>(std::move(batch.sampleTimestamps));

            if constexpr (std::is_same_v<Batch, NumericVisualizationData>) {
              auto dataSharedPtr = std::make_shared<std::vector<double>>(std::move(batch.values));

              visualizationItems->push_back(std::make_shared<VisualizationItem>(VisualizationItem{
                  .id = subscription->id,
                  .valueType = VisualizationValueType::doubleValue,
                  .values = rfl::make_field<"List<double>">(dataSharedPtr),
                  .sampleTimestamps = sampleTimestampsSharedPtr,
              }));
            } else if constexpr (std::is_same_v<Batch, IntegerVisualizationData>) {
              auto dataSharedPtr = std::make_shared<std::vector<int64_t>>(std::move(batch.values));

              visualizationItems->push_back(std::make_shared<VisualizationItem>(VisualizationItem{
                  .id = subscription->id,
                  .valueType = VisualizationValueType::intValue,
                  .values = rfl::make_field<"List<int>">(dataSharedPtr),
                  .sampleTimestamps = sampleTimestampsSharedPtr,
              }));
            } else if constexpr (std::is_same_v<Batch, StringVisualizationData>) {
              auto dataSharedPtr =
                  std::make_shared<std::vector<std::string>>(std::move(batch.values));

              visualizationItems->push_back(std::make_shared<VisualizationItem>(VisualizationItem{
                  .id = subscription->id,
                  .valueType = VisualizationValueType::stringValue,
                  .values = rfl::make_field<"List<String>">(dataSharedPtr),
                  .sampleTimestamps = sampleTimestampsSharedPtr,
              }));
            }
          },
          std::move(data.value()));
    }
  }

  if (visualizationItems->empty()) {
    return;
  }

  // Create a VisualizationUpdateEvent message and send it to the UI
  Response visualizationUpdate = VisualizationUpdateEvent{.items = visualizationItems,
      .responseBase = ResponseBase{
          // Usually, the response ID is the same as the ID of the request that was
          // sent to the engine. In this case, there was no request, so we set it to
          // -1.
          .id = -1,
      }};

  auto responseText = rfl::json::write(visualizationUpdate);
  Anthem::getInstance().comms.send(responseText);
}

void VisualizationBroker::dispose() {
  this->stopTimer();
  this->dataProviders.clear();
  this->subscriptions.clear();
}
