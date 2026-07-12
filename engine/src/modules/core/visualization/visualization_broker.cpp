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
#include "modules/core/engine.h"

#include <algorithm>
#include <type_traits>
#include <utility>

namespace anthem {

namespace {
template <typename T> using RemoveCvRef = std::remove_cv_t<std::remove_reference_t<T>>;
}

VisualizationProviderRegistration::VisualizationProviderRegistration(
    VisualizationBroker& broker, std::string id, VisualizationDataProvider* provider)
  : broker(&broker), id(std::move(id)), provider(provider) {}

VisualizationProviderRegistration::~VisualizationProviderRegistration() {
  release();
}

VisualizationProviderRegistration::VisualizationProviderRegistration(
    VisualizationProviderRegistration&& other) noexcept
  : broker(other.broker), id(std::move(other.id)), provider(other.provider) {
  other.broker = nullptr;
  other.provider = nullptr;
}

VisualizationProviderRegistration& VisualizationProviderRegistration::operator=(
    VisualizationProviderRegistration&& other) noexcept {
  if (this != &other) {
    release();

    broker = other.broker;
    id = std::move(other.id);
    provider = other.provider;

    other.broker = nullptr;
    other.provider = nullptr;
  }

  return *this;
}

void VisualizationProviderRegistration::release() {
  if (broker == nullptr || provider == nullptr) {
    return;
  }

  broker->releaseDataProvider(id, provider);

  broker = nullptr;
  id.clear();
  provider = nullptr;
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

void VisualizationBroker::suppressOutboundUpdates() {
  outboundUpdateBehavior = OutboundUpdateBehavior::suppressed;
}

void VisualizationBroker::discardPendingUpdatesThenResume() {
  outboundUpdateBehavior = OutboundUpdateBehavior::discardThenResume;
}

VisualizationProviderRegistration VisualizationBroker::registerDataProvider(
    const std::string& name, std::unique_ptr<VisualizationDataProvider> provider) {
  if (provider == nullptr) {
    jassertfalse;
    return VisualizationProviderRegistration();
  }

  if (currentDataProviders.find(name) != currentDataProviders.end()) {
    juce::Logger::writeToLog(
        juce::String("Warning: replacing visualization provider for duplicate ID '") +
        juce::String(name) +
        "'. This can happen during processing graph handoff; otherwise, IDs should be unique.");
  }

  auto entry = std::make_unique<ProviderEntry>(ProviderEntry{
      .id = name,
      .provider = std::move(provider),
  });

  auto* entryPtr = entry.get();
  auto* providerPtr = entryPtr->provider.get();

  dataProviders.push_back(std::move(entry));
  currentDataProviders[name] = entryPtr;

  return VisualizationProviderRegistration(*this, name, providerPtr);
}

void VisualizationBroker::releaseDataProvider(
    const std::string& name, VisualizationDataProvider* provider) {
  if (provider == nullptr) {
    return;
  }

  auto currentIter = currentDataProviders.find(name);
  const bool releasingCurrent =
      currentIter != currentDataProviders.end() && currentIter->second->provider.get() == provider;

  auto providerIter = std::find_if(
      dataProviders.begin(), dataProviders.end(), [&](const std::unique_ptr<ProviderEntry>& entry) {
        return entry != nullptr && entry->id == name && entry->provider.get() == provider;
      });

  if (providerIter == dataProviders.end()) {
    return;
  }

  dataProviders.erase(providerIter);

  if (!releasingCurrent) {
    return;
  }

  auto replacementIter = std::find_if(dataProviders.rbegin(),
      dataProviders.rend(),
      [&](const std::unique_ptr<ProviderEntry>& entry) {
        return entry != nullptr && entry->id == name;
      });

  if (replacementIter == dataProviders.rend()) {
    currentDataProviders.erase(name);
    return;
  }

  currentDataProviders[name] = replacementIter->get();
}

VisualizationDataProvider* VisualizationBroker::getCurrentDataProviderForTesting(
    const std::string& name) const {
  auto iter = currentDataProviders.find(name);
  if (iter == currentDataProviders.end()) {
    return nullptr;
  }

  return iter->second->provider.get();
}

size_t VisualizationBroker::getDataProviderCountForTesting(const std::string& name) const {
  return static_cast<size_t>(std::count_if(
      dataProviders.begin(), dataProviders.end(), [&](const std::unique_ptr<ProviderEntry>& entry) {
        return entry != nullptr && entry->id == name;
      }));
}

void VisualizationBroker::discardPendingProviderData() {
  for (const auto& entry : dataProviders) {
    if (entry == nullptr || entry->provider == nullptr) {
      continue;
    }

    entry->provider->getData();
  }
}

void VisualizationBroker::timerCallback() {
  if (outboundUpdateBehavior == OutboundUpdateBehavior::suppressed) {
    return;
  }

  if (outboundUpdateBehavior == OutboundUpdateBehavior::discardThenResume) {
    discardPendingProviderData();
    outboundUpdateBehavior = OutboundUpdateBehavior::sending;
    return;
  }

  if (this->subscriptions.empty()) {
    return;
  }

  auto visualizationItems = std::make_shared<std::vector<std::shared_ptr<VisualizationItem>>>();

  // Iterate over all subscriptions and query the data providers for updates
  for (const auto& subscription : this->subscriptions) {
    auto it = this->currentDataProviders.find(subscription->id);
    if (it != this->currentDataProviders.end()) {
      auto* provider = it->second->provider.get();
      if (provider == nullptr) {
        continue;
      }

      const auto providerValueType = provider->getValueType();
      if (providerValueType != subscription->valueType) {
        jassertfalse;
        continue;
      }

      auto data = provider->getData();
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
  Engine::getInstance().comms.send(responseText);
}

void VisualizationBroker::dispose() {
  this->stopTimer();
  this->dataProviders.clear();
  this->currentDataProviders.clear();
  this->subscriptions.clear();
  this->outboundUpdateBehavior = OutboundUpdateBehavior::sending;
}

} // namespace anthem
