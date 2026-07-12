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

#include "juce_events/juce_events.h"
#include "visualization_provider.h"

#include <memory>
#include <string>
#include <type_traits>
#include <unordered_map>
#include <utility>
#include <vector>

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
// queried and sent to the UI.
namespace anthem {

class VisualizationBroker;

class VisualizationProviderRegistration {
private:
  VisualizationBroker* broker = nullptr;
  std::string id;
  VisualizationDataProvider* provider = nullptr;

  VisualizationProviderRegistration(
      VisualizationBroker& broker, std::string id, VisualizationDataProvider* provider);
public:
  VisualizationProviderRegistration() = default;
  ~VisualizationProviderRegistration();

  VisualizationProviderRegistration(const VisualizationProviderRegistration&) = delete;
  VisualizationProviderRegistration& operator=(const VisualizationProviderRegistration&) = delete;

  VisualizationProviderRegistration(VisualizationProviderRegistration&& other) noexcept;
  VisualizationProviderRegistration& operator=(VisualizationProviderRegistration&& other) noexcept;

  VisualizationDataProvider* get() const {
    return provider;
  }

  void release();

  friend class VisualizationBroker;
};

class VisualizationBroker : private juce::Timer {
private:
  friend class VisualizationProviderRegistration;
  friend class VisualizationBrokerTest;

  struct ProviderEntry {
    std::string id;
    std::unique_ptr<VisualizationDataProvider> provider;
  };

  enum class OutboundUpdateBehavior { sending, suppressed, discardThenResume };

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

  // The UI can remove and add back a graph node with the same visualization ID
  // before the audio thread retires the old graph. Keep stale providers owned
  // until their registrations are released, while routing reads to the newest
  // provider for each ID.
  std::vector<std::unique_ptr<ProviderEntry>> dataProviders;
  std::unordered_map<std::string, ProviderEntry*> currentDataProviders;
  std::vector<std::shared_ptr<VisualizationSubscriptionSpec>> subscriptions;

  // The interval at which the visualization broker updates the UI, in
  // milliseconds
  //
  // Defaults to just faster than 60 FPS (16.67ms). If the UI has a faster
  // refresh rate, this will be set to a lower value.
  double updateIntervalMs;

  OutboundUpdateBehavior outboundUpdateBehavior = OutboundUpdateBehavior::sending;

  void releaseDataProvider(const std::string& name, VisualizationDataProvider* provider);
  void discardPendingProviderData();
  void timerCallback() override;

  VisualizationDataProvider* getCurrentDataProviderForTesting(const std::string& name) const;
  size_t getDataProviderCountForTesting(const std::string& name) const;
public:
  static VisualizationBroker& getInstance() {
    static VisualizationBroker instance;
    return instance;
  }

  void setSubscriptions(
      const std::vector<std::shared_ptr<VisualizationSubscriptionSpec>>& newSubscriptions);
  void setUpdateInterval(double updateIntervalMs);
  void suppressOutboundUpdates();
  void discardPendingUpdatesThenResume();
  VisualizationProviderRegistration registerDataProvider(
      const std::string& name, std::unique_ptr<VisualizationDataProvider> provider);

  void dispose();
};

template <typename Provider> class RegisteredVisualizationProvider {
private:
  static_assert(std::is_base_of_v<VisualizationDataProvider, Provider>);

  Provider* rt_providerPtr = nullptr;
  VisualizationProviderRegistration registration;

  RegisteredVisualizationProvider(
      Provider* rt_providerPtr, VisualizationProviderRegistration registration)
    : rt_providerPtr(rt_providerPtr), registration(std::move(registration)) {}
public:
  RegisteredVisualizationProvider() = default;

  RegisteredVisualizationProvider(const RegisteredVisualizationProvider&) = delete;
  RegisteredVisualizationProvider& operator=(const RegisteredVisualizationProvider&) = delete;

  RegisteredVisualizationProvider(RegisteredVisualizationProvider&& other) noexcept
    : rt_providerPtr(other.rt_providerPtr), registration(std::move(other.registration)) {
    other.rt_providerPtr = nullptr;
  }

  RegisteredVisualizationProvider& operator=(RegisteredVisualizationProvider&& other) noexcept {
    if (this != &other) {
      release();

      rt_providerPtr = other.rt_providerPtr;
      registration = std::move(other.registration);

      other.rt_providerPtr = nullptr;
    }

    return *this;
  }

  static RegisteredVisualizationProvider registerDataProvider(
      const std::string& name, std::unique_ptr<Provider> provider) {
    auto* rt_providerPtr = provider.get();
    auto registration =
        VisualizationBroker::getInstance().registerDataProvider(name, std::move(provider));

    return RegisteredVisualizationProvider(rt_providerPtr, std::move(registration));
  }

  Provider* rt_getProvider() const {
    return rt_providerPtr;
  }

  void release() {
    registration.release();
    rt_providerPtr = nullptr;
  }
};

} // namespace anthem
