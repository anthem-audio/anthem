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

#include "modules/core/engine.h"

#include <juce_core/juce_core.h>

namespace anthem {

class EngineTest : public juce::UnitTest {
public:
  EngineTest() : juce::UnitTest("EngineTest", "Anthem") {}

  void runTest() override {
    beginTest("Engine services are connected before startup and can shut down without starting");
    Engine::cleanup();
    Engine engine;
    expect(!Engine::hasInstance(), "Constructing services must not create another engine.");
    expect(engine.sequenceStore != nullptr);
    expect(engine.automationSequenceStore != nullptr);
    expect(engine.transport != nullptr);
    expect(engine.engineRuntimeServices != nullptr);
    expect(engine.graphProcessor != nullptr);
    expect(engine.globalVisualizationSources != nullptr);
    expect(engine.audioBlockProcessor != nullptr);
    expect(engine.audioSessionController != nullptr);
    expect(engine.renderController != nullptr);

    auto& services = engine.graphProcessor->getEngineRuntimeServices();
    expect(&services == engine.engineRuntimeServices.get());
    expect(&services.rt_getTransport() == engine.transport.get());
    expect(&services.rt_getSequenceStore() == engine.sequenceStore.get());
    expect(&services.rt_getAutomationSequenceStore() == engine.automationSequenceStore.get());
    expect(!engine.audioSessionController->getCurrentAudioProcessingConfig().has_value());
    expect(engine.visualizationComms.getWriter() == nullptr);

    engine.transport->setBeatsPerMinute(90.0);
    engine.transport->rt_beginProcessingBlock(0);
    expectEquals(engine.transport->rt_config->beatsPerMinute, 90.0);
    engine.transport->rt_endProcessingBlock();
    engine.shutdown();
  }
};

static EngineTest engineTest;

} // namespace anthem
