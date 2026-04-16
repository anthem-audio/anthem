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

#include "modules/processing_graph/compiler/actions/anthem_graph_compiler_action.h"
#include "modules/processing_graph/compiler/anthem_graph_compilation_result.h"
#include "modules/processing_graph/runtime/anthem_graph_processor.h"

#include <juce_core/juce_core.h>
#include <memory>
#include <vector>

class AnthemGraphProcessorTest : public juce::UnitTest {
  struct ActionProbe {
    int executeCount = 0;
    int destroyCount = 0;
    int lastNumSamples = -1;
  };

  class ProbeAction : public AnthemGraphCompilerAction {
  public:
    explicit ProbeAction(std::shared_ptr<ActionProbe> probe) : probe(std::move(probe)) {}

    ~ProbeAction() override {
      probe->destroyCount++;
    }

    void execute(int numSamples) override {
      probe->executeCount++;
      probe->lastNumSamples = numSamples;
    }

    void debugPrint() override {}
  private:
    std::shared_ptr<ActionProbe> probe;
  };

  static AnthemGraphCompilationResult* makeCompilationResult(
      const std::shared_ptr<ActionProbe>& probe) {
    auto* result = new AnthemGraphCompilationResult();

    auto actionGroup = std::make_unique<std::vector<std::unique_ptr<AnthemGraphCompilerAction>>>();
    actionGroup->push_back(std::make_unique<ProbeAction>(probe));
    result->actionGroups.push_back(std::move(actionGroup));

    return result;
  }
public:
  AnthemGraphProcessorTest() : juce::UnitTest("AnthemGraphProcessorTest", "Anthem") {}

  void runTest() override {
    testFirstCompilationResultPickup();
    testReplacingActiveCompilationResults();
    testQueuedResultCoalescing();
    testDeletionQueueCleanup();
    testRuntimeServiceReset();
  }

  void testFirstCompilationResultPickup() {
    beginTest("The first queued compilation result becomes active and processes subsequent blocks");

    AnthemGraphProcessor processor;
    auto probe = std::make_shared<ActionProbe>();

    processor.setProcessingStepsFromMainThread(makeCompilationResult(probe));
    processor.process(64);
    processor.process(32);

    expectEquals(probe->executeCount,
        2,
        "The first queued compilation result should become the active graph immediately.");
    expectEquals(probe->lastNumSamples,
        32,
        "Active processing steps should keep receiving later block sizes.");
  }

  void testReplacingActiveCompilationResults() {
    beginTest("New compilation results replace the active result on the next audio block");

    AnthemGraphProcessor processor;
    auto firstProbe = std::make_shared<ActionProbe>();
    auto secondProbe = std::make_shared<ActionProbe>();

    processor.setProcessingStepsFromMainThread(makeCompilationResult(firstProbe));
    processor.process(16);

    processor.setProcessingStepsFromMainThread(makeCompilationResult(secondProbe));
    processor.process(8);

    expectEquals(firstProbe->executeCount,
        1,
        "The old active result should stop executing once a replacement is picked up.");
    expectEquals(secondProbe->executeCount,
        1,
        "The replacement result should execute on the block where it is picked up.");
    expectEquals(
        secondProbe->lastNumSamples, 8, "The replacement should receive the current block size.");
    processor.clearDeletionQueueFromMainThread();
  }

  void testQueuedResultCoalescing() {
    beginTest(
        "Queued compilation results coalesce down to the most recent result before execution");

    AnthemGraphProcessor processor;
    auto olderProbe = std::make_shared<ActionProbe>();
    auto newerProbe = std::make_shared<ActionProbe>();

    processor.setProcessingStepsFromMainThread(makeCompilationResult(olderProbe));
    processor.setProcessingStepsFromMainThread(makeCompilationResult(newerProbe));
    processor.process(24);

    expectEquals(olderProbe->executeCount,
        0,
        "Older queued results should be replaced before they execute.");
    expectEquals(
        newerProbe->executeCount, 1, "Only the newest queued result should execute for the block.");

    processor.clearDeletionQueueFromMainThread();
    expectEquals(olderProbe->destroyCount,
        1,
        "Coalesced results should move through the deletion queue for cleanup.");
  }

  void testDeletionQueueCleanup() {
    beginTest("Clearing the deletion queue deletes replaced compilation results");

    AnthemGraphProcessor processor;
    auto oldProbe = std::make_shared<ActionProbe>();
    auto newProbe = std::make_shared<ActionProbe>();

    processor.setProcessingStepsFromMainThread(makeCompilationResult(oldProbe));
    processor.process(4);

    processor.setProcessingStepsFromMainThread(makeCompilationResult(newProbe));
    processor.process(4);

    expectEquals(oldProbe->destroyCount,
        0,
        "Replaced results should remain alive until the main thread clears the deletion queue.");

    processor.clearDeletionQueueFromMainThread();

    expectEquals(oldProbe->destroyCount,
        1,
        "Clearing the deletion queue should delete the replaced result.");
  }

  void testRuntimeServiceReset() {
    beginTest("Resetting runtime services resets the live note ID generator");

    AnthemGraphProcessor processor;

    expectEquals(processor.getRtServices().rt_allocateLiveNoteId(),
        0,
        "Live note IDs should start from zero.");
    expectEquals(processor.getRtServices().rt_allocateLiveNoteId(),
        1,
        "Live note IDs should increment while runtime services stay active.");

    processor.resetRtServices();

    expectEquals(processor.getRtServices().rt_allocateLiveNoteId(),
        0,
        "Resetting runtime services should reset the live note ID stream.");
  }
};

static AnthemGraphProcessorTest anthemGraphProcessorTest;
