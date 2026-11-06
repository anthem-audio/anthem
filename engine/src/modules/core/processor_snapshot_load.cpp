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

#include "engine.h"
#include "processor_description.h"
#include "processor_state_snapshot.h"
#include "processor_state_storage.h"

#include <stdexcept>

namespace anthem {

// The UI reconciles the returned description before requesting publication.
// Keeping this session alive keeps the node paused across that IPC boundary.
class ProcessorSnapshotLoad : public std::enable_shared_from_this<ProcessorSnapshotLoad> {
public:
  enum class Phase { reading, restoring, awaitingModel, awaitingGraph, failed, finished };
  ProcessorSnapshotLoad(ProcessorStateStorage& owner,
      Engine& engine,
      std::shared_ptr<Node> node,
      int64_t id,
      ProcessorSnapshotLoadCompletion complete)
    : files(owner.files), engine(engine), node(std::move(node)), id(id),
      generation(engine.audioSessionController->getAudioProcessingConfigGeneration()),
      complete(std::move(complete)) {}

  ~ProcessorSnapshotLoad() {
    releaseReads();
  }

  FileStorageClient& files;
  Engine& engine;
  std::shared_ptr<Node> node;
  int64_t id;
  uint64_t generation;
  Phase phase = Phase::reading;
  std::shared_ptr<NodeProcessingPause> pause;
  std::optional<FileStorageAccess> targetRead, recoveryRead;
  ProcessorSnapshotLoadCompletion complete;
  std::shared_ptr<ProcessingGraphNodeInitializationResult> description;
  std::optional<std::string> loadError;
  uint64_t publication = 0;
  double deadline = juce::Time::getMillisecondCounterHiRes() + 25000;
  bool cancelled = false;
  bool mutated = false;

  bool isCurrent() const {
    return engine.project &&
           engine.project->processingGraph()->nodes()->find(node->id()) !=
               engine.project->processingGraph()->nodes()->end() &&
           engine.project->processingGraph()->nodes()->at(node->id()) == node;
  }
  bool isValid() const {
    return !cancelled && isCurrent() &&
           generation == engine.audioSessionController->getAudioProcessingConfigGeneration() &&
           engine.audioSessionController->hasActiveAudioSession() &&
           !engine.renderController->isRendering();
  }
  void reply(std::optional<std::string> error = std::nullopt) {
    if (!complete)
      return;
    auto callback = std::move(complete);
    callback({.operationId = mutated ? std::optional(id) : std::nullopt,
        .result = description,
        .error = std::move(error)});
  }
  void fail(std::string error) {
    if (mutated) {
      node->getProcessor()->isPrepared = false;
      description = makeNodeInitializationResult(node->id(), false, error);
      phase = Phase::failed;
    } else {
      phase = Phase::finished;
      pause.reset();
      releaseReads();
    }
    reply(std::move(error));
  }
  void releaseReads() {
    if (cancelled) {
      // Shutdown has ended request delivery. The UI reclaims this session's
      // file scope after the process exits; don't enqueue cleanup IPC here.
      targetRead.reset();
      recoveryRead.reset();
      return;
    }
    if (targetRead) {
      auto token = std::move(targetRead->token);
      targetRead.reset();
      files.releaseRead(std::move(token), [](auto) {});
    }
    if (recoveryRead) {
      auto token = std::move(recoveryRead->token);
      recoveryRead.reset();
      files.releaseRead(std::move(token), [](auto) {});
    }
  }
  void read(std::string retentionId, FileStorageClient::AccessCompletion callback) {
    files.resolveRetention(std::move(retentionId),
        [self = shared_from_this(), callback = std::move(callback)](
            FileStorageResult<std::string> path) mutable {
          if (self->cancelled)
            return;
          if (path.error)
            callback({.value = std::nullopt, .error = std::move(path.error)});
          else
            self->files.acquireRead(*path.value, std::move(callback));
        });
  }
  void start(std::string retentionId, std::string recoveryId) {
    read(std::move(retentionId),
        [self = shared_from_this(), recoveryId = std::move(recoveryId)](
            FileStorageResult<FileStorageAccess> result) mutable {
          if (result.error) {
            self->fail(*result.error);
            return;
          }
          self->targetRead = std::move(result.value);
          self->read(std::move(recoveryId), [self](FileStorageResult<FileStorageAccess> recovery) {
            if (recovery.error) {
              self->fail(*recovery.error);
              return;
            }
            self->recoveryRead = std::move(recovery.value);
            if (!self->isValid()) {
              self->fail("Snapshot loading was interrupted.");
              return;
            }
            try {
              // Validate both files before mutation, one buffer at a time.
              // Read grants remain alive, but state bytes never span async work.
              {
                ProcessorStateSnapshot targetState(juce::File(self->targetRead->absolutePath));
              }
              {
                ProcessorStateSnapshot recoveryState(juce::File(self->recoveryRead->absolutePath));
              }
            } catch (const std::exception& error) {
              self->fail(error.what());
              return;
            }
            self->engine.graphProcessor->pauseNode(self->node->id(),
                [self](
                    std::shared_ptr<NodeProcessingPause> pause, std::optional<std::string> error) {
                  if (error) {
                    self->fail(*error);
                    return;
                  }
                  self->pause = std::move(pause);
                  self->restore(false);
                });
          });
        });
  }
  void restore(bool recovery) {
    if (!isValid()) {
      fail("Snapshot loading was interrupted.");
      return;
    }
    phase = Phase::restoring;
    deadline = juce::Time::getMillisecondCounterHiRes() + 25000;
    auto processor = node->getProcessor();
    processor->isPrepared = false;
    mutated = true;
    try {
      {
        ProcessorStateSnapshot state(
            juce::File(recovery ? recoveryRead->absolutePath : targetRead->absolutePath));
        state.restore(*processor);
      }
      processor->prepareToProcess(
          [self = shared_from_this(), recovery](std::optional<ProcessorPrepareResult> result) {
            if (self->phase != Phase::restoring)
              return;
            if (!self->isValid()) {
              self->fail("Snapshot loading was interrupted.");
              return;
            }
            try {
              if (!result || !result->success || !result->portConfiguration)
                throw std::runtime_error(
                    result && result->error ? *result->error : "Processor preparation failed.");
              const auto processor = self->node->getProcessor();
              processor->reconcileParameters(*result);
              result->parameterValues = processor->getParameterValues();
              self->description = makeNodeInitializationResult(self->node->id(), *result);
              self->phase = Phase::awaitingModel;
              self->reply(self->loadError);
            } catch (const std::exception& error) {
              self->restoreFailed(recovery, error.what());
            }
          });
    } catch (const std::exception& error) {
      restoreFailed(recovery, error.what());
    }
  }
  void restoreFailed(bool recovery, std::string error) {
    if (recovery) {
      fail("Snapshot recovery failed: " + error);
      return;
    }
    loadError = "Snapshot loading failed: " + error;
    restore(true);
  }
  void finish(bool rollback, ProcessorSnapshotLoadCompletion callback) {
    if (complete || (phase != Phase::awaitingModel && !(rollback && phase == Phase::failed))) {
      callback({.operationId = id,
          .result = nullptr,
          .error = "Snapshot load is not awaiting reconciliation."});
      return;
    }
    complete = std::move(callback);
    if (!isValid()) {
      fail("Snapshot loading was interrupted.");
      return;
    }
    if (rollback) {
      loadError.reset();
      restore(true);
      return;
    }
    try {
      node->getProcessor()->isPrepared = true;
      publication = engine.publishProcessingGraph();
      if (!publication)
        throw std::runtime_error("The processing graph could not be published.");
      phase = Phase::awaitingGraph;
      deadline = juce::Time::getMillisecondCounterHiRes() + 10000;
      poll();
    } catch (const std::exception& error) {
      fail(error.what());
    }
  }
  void poll() {
    if (phase == Phase::finished || phase == Phase::failed)
      return;
    if (!isValid()) {
      fail("Snapshot loading was interrupted.");
      return;
    }
    if (juce::Time::getMillisecondCounterHiRes() > deadline) {
      fail("Snapshot loading timed out. Restart the engine to restore the recovery snapshot.");
      return;
    }
    // A prepared render session has no audio thread until rendering starts.
    // Its first block drains all queued graph publications before processing.
    if (phase == Phase::awaitingGraph &&
        (engine.graphProcessor->isPublicationActive(publication) ||
            !engine.audioSessionController->isRealtimeAudioRunning())) {
      description->parameterValues =
          makeParameterValueList(node->getProcessor()->getParameterValues());
      pause.reset();
      phase = Phase::finished;
      releaseReads();
      reply();
    }
  }
  void cancel() {
    cancelled = true;
    if (mutated)
      node->getProcessor()->isPrepared = false;
    phase = Phase::finished;
    reply("Snapshot loading was cancelled.");
    releaseReads();
    // GraphProcessor::shutdown cancels the gate before this claim is released.
  }
};

ProcessorStateStorage::ProcessorStateStorage(FileStorageClient& files)
  : files(files), maintenance([this]() { pollLoads(); }) {}
ProcessorStateStorage::~ProcessorStateStorage() {
  close();
}

bool ProcessorStateStorage::isBusy(int64_t nodeId) const {
  if (activity->saves.contains(nodeId))
    return true;
  for (const auto& [_, load] : loads)
    if (load->node->id() == nodeId && load->phase != ProcessorSnapshotLoad::Phase::finished)
      return true;
  return false;
}
bool ProcessorStateStorage::hasPendingOperations() const {
  if (!activity->saves.empty() || !activity->captures.empty())
    return true;
  for (const auto& [_, load] : loads)
    if (load->phase != ProcessorSnapshotLoad::Phase::finished &&
        load->phase != ProcessorSnapshotLoad::Phase::failed)
      return true;
  return false;
}
void ProcessorStateStorage::loadSnapshot(Engine& engine,
    const std::shared_ptr<Node>& node,
    std::string retentionId,
    std::string recoveryRetentionId,
    ProcessorSnapshotLoadCompletion complete) {
  if (activity->closed || isBusy(node->id()) || activity->captures.contains(node->id()) ||
      engine.renderController->isRendering() || !node->getProcessor()->isPrepared ||
      !node->getProcessor()->hasRestoredProjectState ||
      !engine.audioSessionController->hasActiveAudioSession()) {
    complete({.operationId = std::nullopt,
        .result = nullptr,
        .error = "The processor is not available for snapshot loading."});
    return;
  }
  auto id = ++nextOperationId;
  auto load = std::make_shared<ProcessorSnapshotLoad>(*this, engine, node, id, std::move(complete));
  loads.emplace(id, load);
  maintenance.startTimer(5);
  load->start(std::move(retentionId), std::move(recoveryRetentionId));
}
void ProcessorStateStorage::finishSnapshotLoad(
    int64_t id, bool rollback, ProcessorSnapshotLoadCompletion complete) {
  auto found = loads.find(id);
  if (found == loads.end()) {
    complete({.operationId = std::nullopt,
        .result = nullptr,
        .error = "Snapshot load operation not found."});
    return;
  }
  found->second->finish(rollback, std::move(complete));
}
void ProcessorStateStorage::pollLoads() {
  // Completions can reenter the service. Iterate a stable copy.
  auto pending = loads;
  for (const auto& [id, load] : pending) {
    load->poll();
    if (load->phase == ProcessorSnapshotLoad::Phase::finished || !load->isCurrent())
      loads.erase(id);
  }
  if (loads.empty())
    maintenance.stopTimer();
}
void ProcessorStateStorage::close() {
  if (activity->closed)
    return;
  activity->closed = true;
  maintenance.stopTimer();
  for (auto& [_, load] : loads)
    load->cancel();
  // Claims remain alive until GraphProcessor shuts down or storage is destroyed.
}

} // namespace anthem
