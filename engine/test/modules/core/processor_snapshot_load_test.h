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
#include "modules/core/processor_state_snapshot.h"
#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processors/utility.h"

namespace anthem {
class ProcessorSnapshotLoadTest : public juce::UnitTest {
  class Probe : public UtilityProcessor {
  public:
    bool failRecovery = false;
    int captures = 0;
    Probe() : UtilityProcessor(UtilityProcessorModelImpl{.nodeId = 1}) {
      prepareToProcess([this](auto result) { reconcileParameters(*result); });
      isPrepared = true;
      hasRestoredProjectState = true;
    }
    void getState(juce::MemoryBlock& bytes) override {
      ++captures;
      const char value = getParameter(gainPortId)->value < 0.3f ? 'x' : 'r';
      bytes.append(&value, 1);
    }
    void setState(const juce::MemoryBlock& bytes) override {
      if (bytes.getSize() && (*static_cast<const char*>(bytes.getData()) == 'x' || failRecovery))
        throw std::runtime_error("Rejected state");
    }
  };
  struct Fixture {
    Engine engine;
    std::shared_ptr<Probe> processor = std::make_shared<Probe>();
    std::shared_ptr<Node> node;
    juce::File target, recovery;
    Fixture() {
      auto graph = graph_test_helpers::makeProcessingGraph();
      node = std::make_shared<Node>(NodeModelImpl{.id = 1,
          .audioInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
          .eventInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
          .controlInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
          .audioOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
          .eventOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
          .controlOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
          .initialParameterValues = std::make_shared<ModelUnorderedMap<int64_t, double>>(),
          .processor =
              rfl::Field<"UtilityProcessorModel", std::shared_ptr<UtilityProcessor>>(processor)});
      graph->nodes()->emplace(1, node);
      engine.project = std::make_shared<Project>(ProjectModelImpl{.processingGraph = graph});
      engine.audioSessionController->startRenderAudioSession(48000, 64, 2);
      const auto temp = juce::File::getSpecialLocation(juce::File::tempDirectory);
      target = temp.getNonexistentChildFile("anthem-load-target", ".bin");
      recovery = temp.getNonexistentChildFile("anthem-load-recovery", ".bin");
      processor->setParameterValue(UtilityProcessor::gainPortId, 0.8);
      ProcessorStateSnapshot(*processor).write(recovery);
      processor->setParameterValue(UtilityProcessor::gainPortId, 0.4);
      ProcessorStateSnapshot(*processor).write(target);
      processor->setParameterValue(UtilityProcessor::gainPortId, 0.8);
    }
    ~Fixture() {
      engine.processorStateStorage.close();
      engine.graphProcessor->shutdown();
      engine.uiRequests.close();
      engine.audioSessionController->stopAudio();
      target.deleteFile();
      recovery.deleteFile();
    }
    void supplyReads() {
      engine.uiRequests.handleResponse(ResolveFileRetentionResponse{
          .relativePath = "plugin states/target.bin", .responseBase = ResponseBase{.id = 0}});
      engine.uiRequests.handleResponse(AcquireFileReadResponse{.token = "target-read",
          .absolutePath = target.getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 1}});
      engine.uiRequests.handleResponse(ResolveFileRetentionResponse{
          .relativePath = "plugin states/recovery.bin", .responseBase = ResponseBase{.id = 2}});
      engine.uiRequests.handleResponse(AcquireFileReadResponse{.token = "recovery-read",
          .absolutePath = recovery.getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 3}});
    }
  };
public:
  ProcessorSnapshotLoadTest() : juce::UnitTest("Processor snapshot loading", "Anthem") {}
  void runTest() override {
    beginTest("Load stays paused until reconciled publication");
    {
      Fixture f;
      std::optional<ProcessorSnapshotLoadResult> loaded;
      f.engine.processorStateStorage.loadSnapshot(
          f.engine, f.node, "target", "recovery", [&](auto result) { loaded = result; });
      expect(!loaded);
      f.supplyReads();
      expect(loaded && !loaded->error && loaded->result->success);
      expectWithinAbsoluteError(
          f.processor->getParameter(UtilityProcessor::gainPortId)->value.load(), 0.4f, 0.0001f);
      expect(!f.processor->rt_tryAcquireProcessingAccess());
      expect(!f.processor->isPrepared);
      std::optional<ProcessorSnapshotLoadResult> finished;
      f.engine.processorStateStorage.finishSnapshotLoad(
          *loaded->operationId, false, [&](auto result) { finished = result; });
      expect(finished && !finished->error);
      expect(f.processor->isPrepared);
      expect(f.processor->rt_tryAcquireProcessingAccess());
      f.processor->rt_releaseProcessingAccess();
      expect(!f.engine.processorStateStorage.isBusy(1));
    }
    beginTest("A restore failure reports recovery configuration and requires reconciliation");
    {
      Fixture f;
      f.processor->setParameterValue(UtilityProcessor::gainPortId, 0.2);
      ProcessorStateSnapshot(*f.processor).write(f.target);
      f.processor->setParameterValue(UtilityProcessor::gainPortId, 0.8);
      std::optional<ProcessorSnapshotLoadResult> loaded;
      f.engine.processorStateStorage.loadSnapshot(
          f.engine, f.node, "target", "recovery", [&](auto result) { loaded = result; });
      f.supplyReads();
      expect(loaded && loaded->error && loaded->result->success);
      expectWithinAbsoluteError(
          f.processor->getParameter(UtilityProcessor::gainPortId)->value.load(), 0.8f, 0.0001f);
      expect(!f.processor->rt_tryAcquireProcessingAccess());
      f.engine.processorStateStorage.finishSnapshotLoad(
          *loaded->operationId, false, [&](auto result) { expect(!result.error); });
      expect(f.processor->rt_tryAcquireProcessingAccess());
      f.processor->rt_releaseProcessingAccess();
    }
    beginTest("Recovery failure never resumes a partially restored processor");
    {
      Fixture f;
      f.processor->failRecovery = true;
      std::optional<ProcessorSnapshotLoadResult> loaded;
      f.engine.processorStateStorage.loadSnapshot(
          f.engine, f.node, "target", "recovery", [&](auto result) { loaded = result; });
      f.supplyReads();
      expect(loaded && loaded->error && !loaded->result->success);
      expect(!f.processor->isPrepared);
      expect(!f.processor->rt_tryAcquireProcessingAccess());
    }
    beginTest("Invalid files fail before live state is changed or paused");
    {
      Fixture f;
      f.target.replaceWithText("invalid snapshot");
      std::optional<ProcessorSnapshotLoadResult> loaded;
      f.engine.processorStateStorage.loadSnapshot(
          f.engine, f.node, "target", "recovery", [&](auto result) { loaded = result; });
      f.supplyReads();
      expect(loaded && loaded->error && !loaded->operationId);
      expect(f.processor->isPrepared);
      expect(f.processor->rt_tryAcquireProcessingAccess());
      f.processor->rt_releaseProcessingAccess();
    }
    beginTest("The caller can roll back before publishing an incompatible configuration");
    {
      Fixture f;
      std::optional<ProcessorSnapshotLoadResult> loaded;
      f.engine.processorStateStorage.loadSnapshot(
          f.engine, f.node, "target", "recovery", [&](auto result) { loaded = result; });
      f.supplyReads();
      std::optional<ProcessorSnapshotLoadResult> recovered;
      f.engine.processorStateStorage.finishSnapshotLoad(
          *loaded->operationId, true, [&](auto result) { recovered = result; });
      expect(recovered && !recovered->error && recovered->result->success);
      expectWithinAbsoluteError(
          f.processor->getParameter(UtilityProcessor::gainPortId)->value.load(), 0.8f, 0.0001f);
      expect(!f.processor->rt_tryAcquireProcessingAccess());
      f.engine.processorStateStorage.finishSnapshotLoad(
          *loaded->operationId, false, [&](auto result) { expect(!result.error); });
      expect(f.processor->rt_tryAcquireProcessingAccess());
      f.processor->rt_releaseProcessingAccess();
    }
    beginTest("A removed node cannot be mutated by delayed file access");
    {
      Fixture f;
      std::optional<ProcessorSnapshotLoadResult> loaded;
      f.engine.processorStateStorage.loadSnapshot(
          f.engine, f.node, "target", "recovery", [&](auto result) { loaded = result; });
      f.engine.project->processingGraph()->nodes()->erase(1);
      f.supplyReads();
      expect(loaded && loaded->error && !loaded->operationId);
      expectWithinAbsoluteError(
          f.processor->getParameter(UtilityProcessor::gainPortId)->value.load(), 0.8f, 0.0001f);
    }
    beginTest("An audio configuration change cannot resume an unconfirmed processor");
    {
      Fixture f;
      std::optional<ProcessorSnapshotLoadResult> loaded;
      f.engine.processorStateStorage.loadSnapshot(
          f.engine, f.node, "target", "recovery", [&](auto result) { loaded = result; });
      f.supplyReads();
      f.engine.audioSessionController->stopAudio();
      f.engine.audioSessionController->startRenderAudioSession(96000, 128, 2);
      std::optional<ProcessorSnapshotLoadResult> finished;
      f.engine.processorStateStorage.finishSnapshotLoad(
          *loaded->operationId, false, [&](auto result) { finished = result; });
      expect(finished && finished->error);
      expect(!f.processor->isPrepared);
      expect(!f.processor->rt_tryAcquireProcessingAccess());
    }
    beginTest("Saving waits for an in-flight processing call before capturing");
    {
      Fixture f;
      const auto count = f.processor->captures;
      expect(f.processor->rt_tryAcquireProcessingAccess());
      std::optional<FileStorageResult<std::string>> saved;
      f.engine.processorStateStorage.saveSnapshot(
          f.engine, f.node, [&](auto result) { saved = result; });
      f.engine.uiRequests.handleResponse(BeginFileWriteResponse{.token = "write",
          .absolutePath = f.target.getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 0}});
      expectEquals(f.processor->captures, count);
      f.processor->rt_releaseProcessingAccess();
      const auto deadline = juce::Time::getMillisecondCounterHiRes() + 2000;
      while (
          f.processor->captures == count && juce::Time::getMillisecondCounterHiRes() < deadline) {
        juce::Timer::callPendingTimersSynchronously();
        juce::Thread::sleep(1);
      }
      expectEquals(f.processor->captures, count + 1);
      expect(!saved);
      f.engine.uiRequests.handleResponse(CommitFileWriteResponse{
          .relativePath = "plugin states/saved.bin", .responseBase = ResponseBase{.id = 1}});
      f.engine.uiRequests.handleResponse(RetainStoredFileResponse{
          .token = "saved-retention", .responseBase = ResponseBase{.id = 2}});
      expect(saved && !saved->error && saved->value == "saved-retention");
      expect(f.processor->rt_tryAcquireProcessingAccess());
      f.processor->rt_releaseProcessingAccess();
    }
    beginTest("Publication acknowledgment only advances when audio adopts a graph");
    {
      Fixture f;
      const auto id = f.engine.publishProcessingGraph();
      expect(id > 0);
      expect(!f.engine.graphProcessor->isPublicationActive(id));
      f.engine.graphProcessor->rt_processGraphUpdates();
      expect(f.engine.graphProcessor->isPublicationActive(id));
      f.engine.graphProcessor->clearRuntimeGraph();
      expect(!f.engine.graphProcessor->isPublicationActive(id));
    }
  }
};
static ProcessorSnapshotLoadTest processorSnapshotLoadTest;
} // namespace anthem
