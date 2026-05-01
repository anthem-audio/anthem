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

class GraphExecutorWorkerThreadStartupScope final {
public:
  GraphExecutorWorkerThreadStartupScope(int workerIndex,
      const juce::String& threadName,
      const GraphExecutor::ThreadConfig& threadConfig) {
    juce::ignoreUnused(workerIndex, threadName, threadConfig);
  }
};

juce::Thread::Priority getGraphExecutorWorkerThreadPriority() {
  return juce::Thread::Priority::high;
}

bool startGraphExecutorWorkerThread(juce::Thread& thread,
    int workerIndex,
    const GraphExecutor::ThreadConfig& threadConfig) {
  juce::ignoreUnused(workerIndex, threadConfig);
  return thread.startThread(getGraphExecutorWorkerThreadPriority());
}

} // namespace

} // namespace anthem
