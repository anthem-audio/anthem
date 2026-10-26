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

#include "modules/core/comms.h"
#include "modules/core/processor_state_storage.h"

#include <juce_cryptography/juce_cryptography.h>
#include <stdexcept>

namespace anthem {

class StorageTestProcessor : public UtilityProcessor {
public:
  StorageTestProcessor() : UtilityProcessor(UtilityProcessorModelImpl{.nodeId = 1}) {
    hasRestoredProjectState = true;
  }
  juce::MemoryBlock state{"test state", 10};
  bool failRestore = false;
  int captureCount = 0;
  void getState(juce::MemoryBlock& target) override {
    ++captureCount;
    target = state;
  }
  void setState(const juce::MemoryBlock& value) override {
    if (failRestore)
      throw std::runtime_error("Restore failed");
    state = value;
  }
};

class ProcessorStateStorageTest : public juce::UnitTest {
public:
  ProcessorStateStorageTest() : juce::UnitTest("ProcessorStateStorageTest", "Anthem") {}

  void runTest() override {
    Comms comms;
    const auto file = juce::File::getSpecialLocation(juce::File::tempDirectory)
                          .getNonexistentChildFile("anthem-state-test", ".bin");
    auto processor = std::make_shared<StorageTestProcessor>();
    const auto node = std::make_shared<Node>(NodeModelImpl{
        .id = 1,
        .isThirdPartyPlugin = false,
        .processorStateRetentionId = "previous-retention",
        .processor =
            rfl::Field<"UtilityProcessorModel", std::shared_ptr<UtilityProcessor>>(processor),
    });
    expect(file.replaceWithData(processor->state.getData(), processor->state.getSize()));

    beginTest(
        "An initialized processor can reuse its state file while its audio session is stopped");
    {
      IpcRequestClient requests(comms);
      FileStorageClient files(requests);
      ProcessorStateStorage storage(files);
      std::optional<FileStorageResult<std::string>> result;
      storage.capture(node, [&](auto value) { result = std::move(value); });
      expect(!result);
      expectEquals(processor->captureCount, 0);
      expect(requests.handleResponse(ResolveFileRetentionResponse{
          .relativePath = "plugin states/previous.bin",
          .responseBase = ResponseBase{.id = 0},
      }));
      expect(requests.handleResponse(AcquireFileReadResponse{
          .token = "read",
          .absolutePath = file.getFullPathName().toStdString(),
          .fingerprint = std::make_shared<FileFingerprint>(FileFingerprint{.byteLength = 10,
              .sha256 = juce::SHA256(processor->state).toHexString().toStdString()}),
          .responseBase = ResponseBase{.id = 1},
      }));
      expectEquals(processor->captureCount, 0);
      expect(requests.handleResponse(BeginFileWriteResponse{
          .token = "write",
          .absolutePath = file.getSiblingFile("unused-state.tmp").getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 2},
      }));
      expectEquals(processor->captureCount, 1);
      expect(!result);
      expect(requests.handleResponse(FileStorageSuccessResponse{
          .responseBase = ResponseBase{.id = 3},
      }));
      expect(!result);
      expect(requests.handleResponse(FileStorageSuccessResponse{
          .responseBase = ResponseBase{.id = 4},
      }));
      expect(result && !result->error && result->value == "plugin states/previous.bin");
    }

    beginTest(
        "Batched captures wait for their grants and can finish while other commits are pending");
    {
      IpcRequestClient requests(comms);
      FileStorageClient files(requests);
      ProcessorStateStorage storage(files);
      node->processorStateRetentionId() = std::nullopt;
      const auto count = processor->captureCount;
      int completed = 0;
      storage.capture(node, [&](auto value) {
        expect(!value.error);
        ++completed;
      });
      storage.capture(node, [&](auto value) {
        expect(!value.error);
        ++completed;
      });
      expectEquals(processor->captureCount, count);
      const auto first = file.getNonexistentSibling(true);
      const auto second = file.getSiblingFile(file.getFileName() + ".second.tmp");
      for (int64_t id = 0; id < 2; ++id) {
        const auto& destination = id == 0 ? first : second;
        expect(requests.handleResponse(BeginFileWriteResponse{
            .token = "write-" + std::to_string(id),
            .absolutePath = destination.getFullPathName().toStdString(),
            .responseBase = ResponseBase{.id = id},
        }));
        expectEquals(processor->captureCount, count + static_cast<int>(id) + 1);
        juce::MemoryBlock written;
        expect(destination.loadFileAsData(written));
        expect(written == processor->state);
      }
      expectEquals(completed, 0);
      for (int64_t id = 2; id < 4; ++id) {
        expect(requests.handleResponse(CommitFileWriteResponse{
            .relativePath = "plugin states/new-" + std::to_string(id) + ".bin",
            .responseBase = ResponseBase{.id = id},
        }));
      }
      expectEquals(completed, 2);
      expect(first.deleteFile());
      expect(second.deleteFile());
    }

    beginTest("A changed hash replaces a previous file with the same byte length");
    {
      IpcRequestClient requests(comms);
      FileStorageClient files(requests);
      ProcessorStateStorage storage(files);
      node->processorStateRetentionId() = "previous-retention";
      const auto destination = file.getNonexistentSibling(true);
      std::optional<FileStorageResult<std::string>> result;
      storage.capture(node, [&](auto value) { result = std::move(value); });
      expect(requests.handleResponse(ResolveFileRetentionResponse{
          .relativePath = "plugin states/previous.bin",
          .responseBase = ResponseBase{.id = 0},
      }));
      expect(requests.handleResponse(AcquireFileReadResponse{
          .token = "read",
          .absolutePath = file.getFullPathName().toStdString(),
          .fingerprint = std::make_shared<FileFingerprint>(FileFingerprint{.byteLength = 10,
              .sha256 =
                  juce::SHA256(juce::MemoryBlock("other data", 10)).toHexString().toStdString()}),
          .responseBase = ResponseBase{.id = 1},
      }));
      expect(requests.handleResponse(BeginFileWriteResponse{
          .token = "write",
          .absolutePath = destination.getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 2},
      }));
      expect(requests.handleResponse(FileStorageSuccessResponse{
          .responseBase = ResponseBase{.id = 3},
      }));
      expect(!result);
      expect(requests.handleResponse(CommitFileWriteResponse{
          .relativePath = "plugin states/new.bin",
          .responseBase = ResponseBase{.id = 4},
      }));
      expect(result && !result->error && result->value == "plugin states/new.bin");
      expect(destination.deleteFile());
    }

    beginTest("A processor that becomes unavailable while waiting is not captured");
    {
      IpcRequestClient requests(comms);
      FileStorageClient files(requests);
      ProcessorStateStorage storage(files);
      node->processorStateRetentionId() = std::nullopt;
      std::optional<FileStorageResult<std::string>> result;
      const auto count = processor->captureCount;
      storage.capture(node, [&](auto value) { result = std::move(value); });
      processor->hasRestoredProjectState = false;
      expect(requests.handleResponse(BeginFileWriteResponse{
          .token = "write",
          .absolutePath = file.getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 0},
      }));
      expectEquals(processor->captureCount, count);
      expect(requests.handleResponse(FileStorageSuccessResponse{
          .responseBase = ResponseBase{.id = 1},
      }));
      expect(result && result->error);
      processor->hasRestoredProjectState = true;
    }

    beginTest("Empty state aborts the unused write and returns an empty reference");
    {
      IpcRequestClient requests(comms);
      FileStorageClient files(requests);
      ProcessorStateStorage storage(files);
      node->processorStateRetentionId() = std::nullopt;
      processor->state.reset();
      std::optional<FileStorageResult<std::string>> result;
      storage.capture(node, [&](auto value) { result = std::move(value); });
      expect(requests.handleResponse(BeginFileWriteResponse{
          .token = "write",
          .absolutePath = file.getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 0},
      }));
      expect(!result);
      expect(requests.handleResponse(FileStorageSuccessResponse{
          .responseBase = ResponseBase{.id = 1},
      }));
      expect(result && !result->error && result->value && result->value->empty());
      expectEquals(file.getSize(), static_cast<juce::int64>(10));
      processor->state = juce::MemoryBlock("test state", 10);
    }

    beginTest("A failed output file is aborted without publishing a new reference");
    {
      IpcRequestClient requests(comms);
      FileStorageClient files(requests);
      ProcessorStateStorage storage(files);
      node->processorStateRetentionId() = std::nullopt;
      std::optional<FileStorageResult<std::string>> result;
      storage.capture(node, [&](auto value) { result = std::move(value); });
      // A child of an ordinary file cannot be opened as an output stream.
      expect(requests.handleResponse(BeginFileWriteResponse{
          .token = "write",
          .absolutePath = file.getChildFile("blocked").getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 0},
      }));
      expect(!result);
      expect(requests.handleResponse(FileStorageSuccessResponse{
          .responseBase = ResponseBase{.id = 1},
      }));
      expect(result && result->error && !result->value);
      expect(file.existsAsFile());
    }

    beginTest("Restoration applies bytes and releases access even if the processor rejects them");
    for (const bool fail : {false, true}) {
      IpcRequestClient requests(comms);
      FileStorageClient files(requests);
      ProcessorStateStorage storage(files);
      node->processorStateRetentionId() = "previous-retention";
      processor->failRestore = fail;
      processor->state.reset();
      bool completed = false;
      std::optional<std::string> error;
      storage.restore(node, processor, [&](auto value) {
        completed = true;
        error = std::move(value);
      });
      expect(requests.handleResponse(ResolveFileRetentionResponse{
          .relativePath = "plugin states/previous.bin",
          .responseBase = ResponseBase{.id = 0},
      }));
      expect(requests.handleResponse(AcquireFileReadResponse{
          .token = "read",
          .absolutePath = file.getFullPathName().toStdString(),
          .responseBase = ResponseBase{.id = 1},
      }));
      expect(!completed);
      expect(requests.handleResponse(FileStorageSuccessResponse{
          .responseBase = ResponseBase{.id = 2},
      }));
      expect(completed);
      expect(error.has_value() == fail);
      if (!fail)
        expect(processor->state == juce::MemoryBlock("test state", 10));
    }
    expect(file.deleteFile());

    beginTest("Legacy migration fixture matches JUCE's encoding");
    const unsigned char legacyBytes[] = {1, 2, 3};
    expectEquals(juce::MemoryBlock(legacyBytes, 3).toBase64Encoding(), juce::String("3.AHv."));
    const unsigned char binaryBytes[] = {0, 255, 128, 64, 127, 255, 0, 128};
    expectEquals(
        juce::MemoryBlock(binaryBytes, 8).toBase64Encoding(), juce::String("8..7Of.82+..H"));
  }
};

static ProcessorStateStorageTest processorStateStorageTest;

} // namespace anthem
