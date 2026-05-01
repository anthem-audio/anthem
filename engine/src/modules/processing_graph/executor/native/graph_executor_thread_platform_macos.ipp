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

namespace anthem {

namespace {

void logGraphExecutorWorkerThreadStartupResult(int workerIndex, const juce::String& result) {
  juce::Logger::writeToLog("Graph worker " + juce::String(workerIndex) + " " + result);
}

class GraphExecutorWorkerThreadStartupScope final {
public:
  GraphExecutorWorkerThreadStartupScope(int workerIndex,
      const juce::String& threadName,
      const GraphExecutor::ThreadConfig& threadConfig) {
    juce::ignoreUnused(threadName);

    if (!threadConfig.macAudioWorkgroup ||
        static_cast<size_t>(workerIndex) >= threadConfig.platformRealtimeWorkerThreadCount) {
      return;
    }

    threadConfig.macAudioWorkgroup.join(workgroupToken);

    if (!workgroupToken) {
      logGraphExecutorWorkerThreadStartupResult(
          workerIndex, "failed to join the macOS audio workgroup.");
    }
  }

  GraphExecutorWorkerThreadStartupScope(const GraphExecutorWorkerThreadStartupScope&) = delete;
  GraphExecutorWorkerThreadStartupScope& operator=(const GraphExecutorWorkerThreadStartupScope&) =
      delete;

  GraphExecutorWorkerThreadStartupScope(GraphExecutorWorkerThreadStartupScope&&) = delete;
  GraphExecutorWorkerThreadStartupScope& operator=(GraphExecutorWorkerThreadStartupScope&&) =
      delete;
private:
  juce::WorkgroupToken workgroupToken;
};

juce::Thread::Priority getGraphExecutorWorkerThreadPriority() {
  return juce::Thread::Priority::high;
}

bool startGraphExecutorWorkerThread(juce::Thread& thread,
    int workerIndex,
    const GraphExecutor::ThreadConfig& threadConfig) {
  if (static_cast<size_t>(workerIndex) < threadConfig.platformRealtimeWorkerThreadCount &&
      threadConfig.audioBlockSize > 0 && threadConfig.sampleRate > 0.0) {
    auto realtimeOptions = juce::Thread::RealtimeOptions{}.withApproximateAudioProcessingTime(
        threadConfig.audioBlockSize, threadConfig.sampleRate);

    if (thread.startRealtimeThread(realtimeOptions)) {
      return true;
    }

    logGraphExecutorWorkerThreadStartupResult(
        workerIndex, "failed to start as a macOS realtime thread; falling back to high priority.");
  }

  return thread.startThread(getGraphExecutorWorkerThreadPriority());
}

} // namespace

} // namespace anthem
