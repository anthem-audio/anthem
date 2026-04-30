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

// cspell:ignore avrt

namespace anthem {

namespace {

void logGraphExecutorWorkerThreadStartupFailure(int workerIndex, const juce::String& reason) {
  juce::Logger::writeToLog("Graph worker " + juce::String(workerIndex) +
                           " failed to register with MMCSS: " + reason);
}

class GraphExecutorWorkerThreadStartupScope final {
public:
  GraphExecutorWorkerThreadStartupScope(int workerIndex, const juce::String& threadName) {
    juce::ignoreUnused(threadName);

    using AvSetMmThreadCharacteristicsWFn = void*(JUCE_CALLTYPE*)(const wchar_t*, unsigned long*);
    using AvSetMmThreadPriorityFn = int(JUCE_CALLTYPE*)(void*, int);
    using AvRevertMmThreadCharacteristicsFn = int(JUCE_CALLTYPE*)(void*);

    if (!library.open("avrt.dll")) {
      logGraphExecutorWorkerThreadStartupFailure(workerIndex, "avrt.dll could not be loaded.");
      return;
    }

    auto* setThreadCharacteristics = reinterpret_cast<AvSetMmThreadCharacteristicsWFn>(
        library.getFunction("AvSetMmThreadCharacteristicsW"));
    auto* setThreadPriority =
        reinterpret_cast<AvSetMmThreadPriorityFn>(library.getFunction("AvSetMmThreadPriority"));

    revertThreadCharacteristics = reinterpret_cast<AvRevertMmThreadCharacteristicsFn>(
        library.getFunction("AvRevertMmThreadCharacteristics"));

    if (setThreadCharacteristics == nullptr) {
      logGraphExecutorWorkerThreadStartupFailure(
          workerIndex, "AvSetMmThreadCharacteristicsW could not be loaded.");
      return;
    }

    if (setThreadPriority == nullptr) {
      logGraphExecutorWorkerThreadStartupFailure(
          workerIndex, "AvSetMmThreadPriority could not be loaded.");
      return;
    }

    if (revertThreadCharacteristics == nullptr) {
      logGraphExecutorWorkerThreadStartupFailure(
          workerIndex, "AvRevertMmThreadCharacteristics could not be loaded.");
      return;
    }

    unsigned long taskIndex = 0;
    taskHandle = setThreadCharacteristics(L"Pro Audio", &taskIndex);

    if (taskHandle == nullptr) {
      logGraphExecutorWorkerThreadStartupFailure(
          workerIndex, "AvSetMmThreadCharacteristicsW returned a null task handle.");
      return;
    }

    constexpr int avrtPriorityNormal = 0;

    if (setThreadPriority(taskHandle, avrtPriorityNormal) == 0) {
      logGraphExecutorWorkerThreadStartupFailure(workerIndex, "AvSetMmThreadPriority failed.");
    }
  }

  ~GraphExecutorWorkerThreadStartupScope() {
    if (taskHandle != nullptr && revertThreadCharacteristics != nullptr) {
      revertThreadCharacteristics(taskHandle);
    }
  }

  GraphExecutorWorkerThreadStartupScope(const GraphExecutorWorkerThreadStartupScope&) = delete;
  GraphExecutorWorkerThreadStartupScope& operator=(const GraphExecutorWorkerThreadStartupScope&) =
      delete;

  GraphExecutorWorkerThreadStartupScope(GraphExecutorWorkerThreadStartupScope&&) = delete;
  GraphExecutorWorkerThreadStartupScope& operator=(GraphExecutorWorkerThreadStartupScope&&) =
      delete;
private:
  using AvRevertMmThreadCharacteristicsFn = int(JUCE_CALLTYPE*)(void*);

  juce::DynamicLibrary library;
  void* taskHandle = nullptr;
  AvRevertMmThreadCharacteristicsFn revertThreadCharacteristics = nullptr;
};

juce::Thread::Priority getGraphExecutorWorkerThreadPriority() {
  return juce::Thread::Priority::high;
}

} // namespace

} // namespace anthem
