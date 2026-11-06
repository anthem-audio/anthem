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

#include "file_storage_client.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/processor/processor.h"

#include <juce_events/juce_events.h>
#include <unordered_map>
#include <unordered_set>

namespace anthem {
class Engine;
class ProcessorSnapshotLoad;
struct ProcessingGraphNodeInitializationResult;
struct ProcessorSnapshotLoadResult {
  std::optional<int64_t> operationId;
  std::shared_ptr<ProcessingGraphNodeInitializationResult> result;
  std::optional<std::string> error;
};
using ProcessorSnapshotLoadCompletion = std::function<void(ProcessorSnapshotLoadResult)>;

// Captures and restores base values and private state through project storage.
// Calls and completions run on the message thread, never the audio thread.
class ProcessorStateStorage {
public:
  explicit ProcessorStateStorage(FileStorageClient& files);
  ~ProcessorStateStorage();
  void close();

  // Hands the retention token to the caller; the engine must not use or release
  // it afterward. Its session scope retains it until UI adoption or cleanup.
  void saveSnapshot(Engine& engine,
      const std::shared_ptr<Node>& node,
      FileStorageClient::TokenCompletion complete);
  void loadSnapshot(Engine& engine,
      const std::shared_ptr<Node>& node,
      std::string retentionId,
      std::string recoveryRetentionId,
      ProcessorSnapshotLoadCompletion complete);
  void finishSnapshotLoad(
      int64_t operationId, bool rollback, ProcessorSnapshotLoadCompletion complete);
  bool isBusy(int64_t nodeId) const;
  bool hasPendingOperations() const;

  // Returns the previous path if the captured bytes are unchanged. An empty
  // path means the processor has no parameters or private state.
  void capture(const std::shared_ptr<Node>& node,
      FileStorageClient::RelativePathCompletion complete,
      Engine* engine = nullptr);
  void restore(const std::shared_ptr<Node>& node,
      const std::shared_ptr<Processor>& processor,
      FileStorageClient::Completion complete);
private:
  friend class ProcessorSnapshotLoad;
  FileStorageClient& files;
  std::unordered_map<int64_t, std::shared_ptr<ProcessorSnapshotLoad>> loads;
  // Captures can outlive this service while file requests finish or cancel.
  struct Activity {
    std::unordered_set<int64_t> saves;
    std::unordered_map<int64_t, int> captures;
    bool closed = false;
  };
  std::shared_ptr<Activity> activity = std::make_shared<Activity>();
  int64_t nextOperationId = 0;
  juce::TimedCallback maintenance;
  void pollLoads();
};

} // namespace anthem
