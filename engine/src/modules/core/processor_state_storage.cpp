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

#include <juce_cryptography/juce_cryptography.h>
#include <stdexcept>

namespace anthem {
namespace {

std::optional<std::string> writeStateFile(const juce::File& file, const juce::MemoryBlock& state) {
  juce::FileOutputStream output(file);
  if (!output.openedOk() || !output.setPosition(0) || output.truncate().failed() ||
      !output.write(state.getData(), state.getSize()))
    return "Could not write captured processor state.";
  output.flush();
  if (output.getStatus().failed())
    return "Could not flush captured processor state.";
  return std::nullopt;
}

// File grants are acquired before capture. The complete state buffer exists
// only during captureAndWrite(), which does not wait for IPC replies.
class StateCapture : public std::enable_shared_from_this<StateCapture> {
public:
  StateCapture(FileStorageClient& files,
      std::shared_ptr<Node> node,
      FileStorageClient::RelativePathCompletion complete)
    : files(files), node(std::move(node)),
      previousRetentionId(this->node->processorStateRetentionId()), complete(std::move(complete)) {}

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

  bool matchesPrevious(const FileFingerprint& fingerprint) const {
    if (!previousRead || !previousRead->fingerprint)
      return false;
    const auto& previous = *previousRead->fingerprint;
    return previous.byteLength == fingerprint.byteLength && previous.sha256 == fingerprint.sha256;
  }

  FileStorageResult<FileFingerprint> captureAndWrite(const juce::File& destination) {
    const auto processor = node->getProcessor();
    if (!processor || !(*processor)->hasRestoredProjectState)
      return {.value = std::nullopt, .error = "The processor is not initialized."};
    try {
      juce::MemoryBlock state;
      (*processor)->getState(state);
      FileFingerprint fingerprint{
          .byteLength = static_cast<int64_t>(state.getSize()),
          .sha256 = juce::SHA256(state).toHexString().toStdString(),
      };
      if (state.getSize() != 0 && !matchesPrevious(fingerprint)) {
        if (auto error = writeStateFile(destination, state))
          return {.value = std::nullopt, .error = std::move(error)};
      }
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
        [self = shared_from_this()](
            FileStorageResult<FileStorageAccess> access) { self->write(std::move(access)); },
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
    if (access.error) {
      releasePreviousRead(
          [self = shared_from_this(), error = std::move(access.error)](std::optional<std::string>) {
            self->complete({.value = std::nullopt, .error = error});
          });
      return;
    }

    // captureAndWrite closes the stream and frees the buffer before returning.
    auto captured = captureAndWrite(juce::File(access.value->absolutePath));
    releasePreviousRead(
        [self = shared_from_this(), token = access.value->token, captured = std::move(captured)](
            std::optional<std::string> error) mutable {
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

void ProcessorStateStorage::capture(
    const std::shared_ptr<Node>& node, FileStorageClient::RelativePathCompletion complete) {
  auto processor = node->getProcessor();
  if (!processor || !(*processor)->hasRestoredProjectState) {
    complete({.value = std::nullopt, .error = "The processor is not initialized."});
    return;
  }
  std::make_shared<StateCapture>(files, node, std::move(complete))->start();
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
                juce::MemoryBlock state;
                if (!juce::File(access.value->absolutePath).loadFileAsData(state))
                  throw std::runtime_error("Could not read saved processor state.");
                processor->setState(state);
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
