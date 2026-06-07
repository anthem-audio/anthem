/*
  Copyright (C) 2026 Joshua Wade

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

#include "modules/core/visualization/visualization_broker.h"
#include "modules/core/visualization/visualization_provider.h"

#include <juce_core/juce_core.h>
#include <memory>
#include <optional>

namespace anthem {

class VisualizationBrokerTestProvider
  : public TypedVisualizationDataProvider<double, VisualizationValueType::doubleValue> {
public:
  std::optional<NumericVisualizationData> getTypedData() override {
    return std::nullopt;
  }
};

class VisualizationBrokerTest : public juce::UnitTest {
public:
  VisualizationBrokerTest() : juce::UnitTest("VisualizationBrokerTest", "Anthem") {}

  void runTest() override {
    testDuplicateIdReleaseKeepsNewestProvider();
    testCurrentDuplicateReleaseFallsBackToPreviousProvider();
  }

  void testDuplicateIdReleaseKeepsNewestProvider() {
    beginTest("Duplicate visualization ID release keeps the newest provider current");

    auto& broker = VisualizationBroker::getInstance();
    const std::string id = "visualization-broker-test-duplicate-id";

    auto firstProvider = std::make_unique<VisualizationBrokerTestProvider>();
    auto* firstProviderPtr = firstProvider.get();
    auto firstRegistration = broker.registerDataProvider(id, std::move(firstProvider));

    expectEquals(
        static_cast<int>(broker.getDataProviderCountForTesting(id)), 1, "First provider is owned");
    expect(broker.getCurrentDataProviderForTesting(id) == firstProviderPtr,
        "First provider should be current");

    auto secondProvider = std::make_unique<VisualizationBrokerTestProvider>();
    auto* secondProviderPtr = secondProvider.get();
    auto secondRegistration = broker.registerDataProvider(id, std::move(secondProvider));

    expectEquals(static_cast<int>(broker.getDataProviderCountForTesting(id)),
        2,
        "Both providers should remain owned during handoff");
    expect(broker.getCurrentDataProviderForTesting(id) == secondProviderPtr,
        "Second provider should become current");

    firstRegistration.release();

    expectEquals(static_cast<int>(broker.getDataProviderCountForTesting(id)),
        1,
        "Releasing the stale provider should remove only that provider");
    expect(broker.getCurrentDataProviderForTesting(id) == secondProviderPtr,
        "Second provider should remain current after stale release");

    secondRegistration.release();

    expectEquals(
        static_cast<int>(broker.getDataProviderCountForTesting(id)), 0, "All providers released");
    expect(broker.getCurrentDataProviderForTesting(id) == nullptr,
        "No provider should remain current after releasing the newest provider");
  }

  void testCurrentDuplicateReleaseFallsBackToPreviousProvider() {
    beginTest("Duplicate visualization ID release falls back to the previous provider");

    auto& broker = VisualizationBroker::getInstance();
    const std::string id = "visualization-broker-test-fallback-id";

    auto firstProvider = std::make_unique<VisualizationBrokerTestProvider>();
    auto* firstProviderPtr = firstProvider.get();
    auto firstRegistration = broker.registerDataProvider(id, std::move(firstProvider));

    auto secondProvider = std::make_unique<VisualizationBrokerTestProvider>();
    auto* secondProviderPtr = secondProvider.get();
    auto secondRegistration = broker.registerDataProvider(id, std::move(secondProvider));

    expect(broker.getCurrentDataProviderForTesting(id) == secondProviderPtr,
        "Second provider should start as current");

    secondRegistration.release();

    expectEquals(static_cast<int>(broker.getDataProviderCountForTesting(id)),
        1,
        "Releasing the current provider should remove only that provider");
    expect(broker.getCurrentDataProviderForTesting(id) == firstProviderPtr,
        "First provider should become current again");

    firstRegistration.release();

    expectEquals(
        static_cast<int>(broker.getDataProviderCountForTesting(id)), 0, "All providers released");
    expect(broker.getCurrentDataProviderForTesting(id) == nullptr,
        "No provider should remain current after releasing the last provider");
  }
};

static VisualizationBrokerTest visualizationBrokerTest;

} // namespace anthem
