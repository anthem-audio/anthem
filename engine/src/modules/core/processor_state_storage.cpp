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

#include "processor_state_storage.h"

#include "engine.h"
#include "modules/processors/master_output.h"
#include "processor_state_snapshot.h"

#include <juce_cryptography/juce_cryptography.h>
#include <stdexcept>

namespace anthem {
namespace {

// File grants are acquired before capture. The complete state buffer exists
// only during captureAndWrite(), which does not wait for IPC replies.
class StateCapture : public std::enable_shared_from_this<StateCapture> {
public:
  StateCapture(FileStorageClient& files,
      std::shared_ptr<Node> node,
      FileStorageClient::RelativePathCompletion complete,
      Engine* engine = nullptr,
      bool includeEmpty = false)
    : files(files), node(std::move(node)),
      previousRetentionId(this->node->processorStateRetentionId()), complete(std::move(complete)),
      engine(engine), includeEmpty(includeEmpty) {}

  void start() {
    if (!previousRetentionId) {
      beginWrite();
      return;
    }
    files.resolveRetention(
        *previousRetentionId, [self = shared_from_this()](FileStorageResult<std::string> path) {
          if (path.error) {
            self->beginWrite();
            return;
          }
          self->previousPath = std::move(path.value);
          self->files.acquireRead(
              *self->previousPath,
              [self](FileStorageResult<FileStorageAccess> access) {
                // A live processor can replace a missing or unreadable old file.
                if (!access.error)
                  self->previousRead = std::move(access.value);
                self->beginWrite();
              },
              true);
        });
  }
private:
  FileStorageClient& files;
  std::shared_ptr<Node> node;
  std::optional<std::string> previousRetentionId;
  std::optional<std::string> previousPath;
  std::optional<FileStorageAccess> previousRead;
  FileStorageClient::RelativePathCompletion complete;

  Engine* engine;
  bool includeEmpty;
  std::shared_ptr<NodeProcessingPause> pause;

  bool matchesPrevious(const FileFingerprint& fingerprint) const {
    if (!previousRead || !previousRead->fingerprint)
      return false;
    const auto& previous = *previousRead->fingerprint;
    return previous.byteLength == fingerprint.byteLength && previous.sha256 == fingerprint.sha256;
  }

  FileStorageResult<FileFingerprint> captureAndWrite(const juce::File& destination) {
    const auto processor = node->getProcessor();
    if (engine != nullptr &&
        (!engine->project ||
            engine->project->processingGraph()->nodes()->find(node->id()) ==
                engine->project->processingGraph()->nodes()->end() ||
            engine->project->processingGraph()->nodes()->at(node->id()) != node ||
            engine->renderController->isRendering()))
      return {.value = std::nullopt, .error = "Snapshot capture was interrupted."};
    if (!processor->hasRestoredProjectState)
      return {.value = std::nullopt, .error = "The processor is not initialized."};
    try {
      ProcessorStateSnapshot state(*processor);
      // The independent bytes no longer need processor access. Disk I/O and
      // hashing can proceed while the node processes its next block.
      pause.reset();
      auto fingerprint = (!includeEmpty && state.isEmpty())
                             ? FileFingerprint{.byteLength = 0, .sha256 = ""}
                             : state.fingerprint();
      if ((includeEmpty || !state.isEmpty()) && !matchesPrevious(fingerprint))
        state.write(destination);
      return {.value = std::move(fingerprint), .error = std::nullopt};
    } catch (const std::exception& error) {
      return {.value = std::nullopt, .error = error.what()};
    }
  }

  void releasePreviousRead(FileStorageClient::Completion onComplete) {
    if (previousRead)
      files.releaseRead(previousRead->token, std::move(onComplete));
    else
      onComplete(std::nullopt);
  }

  void beginWrite() {
    files.beginWrite(
        "plugin states",
        [self = shared_from_this()](FileStorageResult<FileStorageAccess> access) {
          if (!self->engine || access.error) {
            self->write(std::move(access));
            return;
          }
          self->engine->graphProcessor->pauseNode(self->node->id(),
              [self, access = std::move(access)](std::shared_ptr<NodeProcessingPause> pause,
                  const std::optional<std::string>& error) mutable {
                if (error) {
                  self->releasePreviousRead(
                      [self, token = access.value->token, error](const auto&) {
                        self->abortAndComplete(token, {.value = std::nullopt, .error = error});
                      });
                  return;
                }
                self->pause = std::move(pause);
                self->write(std::move(access));
              });
        },
        std::nullopt,
        std::string("bin"));
  }

  void abortAndComplete(std::string token, FileStorageResult<std::string> result) {
    files.abortWrite(std::move(token),
        [self = shared_from_this(), result = std::move(result)](
            std::optional<std::string> error) mutable {
          if (error && !result.error) {
            result.value = std::nullopt;
            result.error = std::move(error);
          }
          self->complete(std::move(result));
        });
  }

  void write(FileStorageResult<FileStorageAccess> access) {
    if (access.error || !access.value) {
      releasePreviousRead(
          [self = shared_from_this(),
              error = access.error.value_or("File storage returned no write access.")](
              const std::optional<std::string>&) {
            self->complete({.value = std::nullopt, .error = error});
          });
      return;
    }

    // captureAndWrite closes the stream and frees the buffer before returning.
    const auto& grant = *access.value;
    auto captured = captureAndWrite(juce::File(grant.absolutePath));
    pause.reset();
    releasePreviousRead(
        [self = shared_from_this(), token = grant.token, captured = std::move(captured)](
            const std::optional<std::string>& error) mutable {
          if (captured.error || error) {
            self->abortAndComplete(
                token, {.value = std::nullopt, .error = captured.error ? captured.error : error});
          } else if (captured.value->byteLength == 0 || self->matchesPrevious(*captured.value)) {
            self->abortAndComplete(token,
                {.value = captured.value->byteLength == 0 ? std::string() : self->previousPath,
                    .error = std::nullopt});
          } else {
            self->files.commitWrite(
                token,
                [self, token](FileStorageResult<std::string> result) {
                  if (result.error)
                    self->abortAndComplete(token, std::move(result));
                  else
                    self->complete(std::move(result));
                },
                std::move(captured.value));
          }
        });
  }
};

} // namespace

void ProcessorStateStorage::capture(const std::shared_ptr<Node>& node,
    FileStorageClient::RelativePathCompletion complete,
    Engine* engine) {
  if (activity->closed || isBusy(node->id()) ||
      (engine != nullptr && engine->renderController->isRendering())) {
    complete({.value = std::nullopt, .error = "A processor state operation is in progress."});
    return;
  }
  auto processor = node->getProcessor();
  // The master endpoint is stateless and cannot participate in node pauses.
  if (engine != nullptr && std::dynamic_pointer_cast<MasterOutputProcessor>(processor)) {
    complete({.value = std::string(), .error = std::nullopt});
    return;
  }
  if (!processor->hasRestoredProjectState) {
    complete({.value = std::nullopt, .error = "The processor is not initialized."});
    return;
  }
  ++activity->captures[node->id()];
  std::make_shared<StateCapture>(
      files,
      node,
      [activity = activity, id = node->id(), complete = std::move(complete)](
          FileStorageResult<std::string> result) mutable {
        if (--activity->captures[id] == 0)
          activity->captures.erase(id);
        complete(std::move(result));
      },
      engine)
      ->start();
}

void ProcessorStateStorage::saveSnapshot(Engine& engine,
    const std::shared_ptr<Node>& node,
    FileStorageClient::TokenCompletion complete) {
  if (activity->closed || isBusy(node->id()) || activity->captures.contains(node->id()) ||
      engine.renderController->isRendering()) {
    complete({.value = std::nullopt,
        .error = "Cannot save a snapshot during another state operation or render."});
    return;
  }
  activity->saves.insert(node->id());
  std::make_shared<StateCapture>(
      files,
      node,
      [activity = activity, &files = files, id = node->id(), complete = std::move(complete)](
          FileStorageResult<std::string> result) mutable {
        if (result.error || activity->closed) {
          activity->saves.erase(id);
          complete({.value = std::nullopt,
              .error = result.error ? result.error : "Processor state storage is closed."});
          return;
        }
        files.retainFile(*result.value,
            [activity, id, complete = std::move(complete)](
                FileStorageResult<std::string> retained) mutable {
              activity->saves.erase(id);
              // Ownership passes to the caller; do not use or release this token again.
              complete(std::move(retained));
            });
      },
      &engine,
      true)
      ->start();
}

void ProcessorStateStorage::restore(const std::shared_ptr<Node>& node,
    const std::shared_ptr<Processor>& processor,
    FileStorageClient::Completion complete) {
  const auto retentionId = node->processorStateRetentionId();
  if (!retentionId.has_value()) {
    complete(std::nullopt);
    return;
  }
  files.resolveRetention(*retentionId,
      [this, processor, complete = std::move(complete)](
          FileStorageResult<std::string> path) mutable {
        if (path.error) {
          complete(std::move(path.error));
          return;
        }
        files.acquireRead(*path.value,
            [this, processor, complete = std::move(complete)](
                FileStorageResult<FileStorageAccess> access) mutable {
              if (access.error) {
                complete(std::move(access.error));
                return;
              }
              std::optional<std::string> error;
              try {
                ProcessorStateSnapshot state(juce::File(access.value->absolutePath));
                state.restore(*processor);
              } catch (const std::exception& exception) {
                error = exception.what();
              }
              files.releaseRead(access.value->token,
                  [complete = std::move(complete), error = std::move(error)](
                      std::optional<std::string> releaseError) mutable {
                    complete(error ? std::move(error) : std::move(releaseError));
                  });
            });
      });
}

} // namespace anthem
