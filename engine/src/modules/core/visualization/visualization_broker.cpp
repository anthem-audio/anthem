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
#include <cmath>
#include <utility>

namespace anthem {

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
  recordPublisher.reset();
}

void VisualizationBroker::setUpdateInterval(double newUpdateIntervalMs) {
  if (!std::isfinite(newUpdateIntervalMs) || newUpdateIntervalMs <= 0)
    return;
  this->updateIntervalMs = std::clamp(newUpdateIntervalMs, 1000.0 / 240.0, 1000.0);

  this->stopTimer();
  this->startTimerHz(static_cast<int>(1000.0 / this->updateIntervalMs));
}

void VisualizationBroker::suppressOutboundUpdates() {
  recordPublisher.reset();
  outboundUpdateBehavior = OutboundUpdateBehavior::suppressed;
}

void VisualizationBroker::discardPendingUpdatesThenResume() {
  recordPublisher.reset();
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
  recordPublisher.discard(name);

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

  recordPublisher.discard(name);

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

  auto& engine = Engine::getInstance();
  auto* writer = engine.visualizationComms.getWriter();
  if (writer == nullptr || engine.audioSessionController == nullptr) {
    return;
  }
  const auto config = engine.audioSessionController->getCurrentAudioProcessingConfigSnapshot();
  if (!config.has_value()) {
    recordPublisher.reset();
    discardPendingProviderData();
    return;
  }

  std::vector<VisualizationRecordItem> items;
  for (const auto& subscription : subscriptions) {
    const auto entry = currentDataProviders.find(subscription->id);
    if (entry == currentDataProviders.end())
      continue;
    auto& provider = *entry->second->provider;
    if (provider.getValueType() != subscription->valueType) {
      jassertfalse;
      continue;
    }
    auto data = provider.getData();
    if (!data.has_value())
      continue;
    const auto valid = std::visit(
        [](const auto& batch) {
          return !batch.values.empty() && batch.values.size() == batch.sampleTimestamps.size() &&
                 std::is_sorted(batch.sampleTimestamps.begin(), batch.sampleTimestamps.end());
        },
        *data);
    if (valid)
      items.push_back(VisualizationRecordItem{subscription->id, std::move(*data)});
  }
  recordPublisher.publish(*writer, config->generation, config->config.sampleRate, std::move(items));
}

void VisualizationBroker::dispose() {
  this->stopTimer();
  this->dataProviders.clear();
  this->currentDataProviders.clear();
  this->subscriptions.clear();
  recordPublisher.reset();
  this->outboundUpdateBehavior = OutboundUpdateBehavior::sending;
}

} // namespace anthem
