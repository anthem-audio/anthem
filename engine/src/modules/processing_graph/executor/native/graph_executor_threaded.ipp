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

#include <algorithm>
#include <atomic>
#include <limits>
#include <memory>
#include <optional>
#include <vector>

#if defined(_MSC_VER)
#include <intrin.h>
#endif

#if JUCE_WINDOWS
#include "graph_executor_thread_platform_windows.ipp"
#elif JUCE_LINUX
#include "graph_executor_thread_platform_linux.ipp"
#elif JUCE_MAC
#include "graph_executor_thread_platform_macos.ipp"
#else
#include "graph_executor_thread_platform_noop.ipp"
#endif

namespace anthem {

namespace {

constexpr int minimumCoreCount = 1;
constexpr int threadStopTimeoutMs = 5000;
constexpr int workerGateSpinAttempts = 100;
constexpr size_t audioThreadReadyQueueIndex = 0;

enum class ExecutorThreadRole {
  audioThread,
  workerThread,
};

inline void spin_pause() noexcept {
#if (defined(__i386__) || defined(__x86_64__)) && (defined(__GNUC__) || defined(__clang__))
  __builtin_ia32_pause();

#elif defined(_MSC_VER) && (defined(_M_IX86) || defined(_M_X64))
  _mm_pause();

#elif (defined(__aarch64__) || defined(__arm__)) && (defined(__GNUC__) || defined(__clang__))
  __asm__ __volatile__("yield" ::: "memory");

#elif defined(_MSC_VER) && (defined(_M_ARM) || defined(_M_ARM64))
  __yield();

#else
#error "The threaded processing graph executor needs a hardware spin pause implementation."
#endif
}

int getAvailableCoreCount() {
  return std::max(minimumCoreCount, juce::SystemStats::getNumPhysicalCpus());
}

int getWorkerThreadCountForCoreCount(int coreCount) {
  jassert(coreCount >= 1);
  return coreCount - 1;
}

size_t getActiveWorkerThreadCount(int workerThreadCount, const GraphExecutor::ThreadConfig& config) {
  const auto availableWorkerThreadCount = static_cast<size_t>(std::max(0, workerThreadCount));

  if (config.maxActiveWorkerThreadCount > 0) {
    return std::min(availableWorkerThreadCount, config.maxActiveWorkerThreadCount);
  }

  return availableWorkerThreadCount;
}

bool canUsePlatformRealtimeThreading(const GraphExecutor::ThreadConfig& config) {
  return config.audioBlockSize > 0 && config.sampleRate > 0.0;
}

GraphExecutor::ThreadConfig buildPreparedThreadConfig(
    int workerThreadCount, const GraphExecutor::ThreadConfig& requestedConfig) {
  auto preparedConfig = requestedConfig;
  preparedConfig.activeWorkerThreadCount =
      getActiveWorkerThreadCount(workerThreadCount, requestedConfig);

  preparedConfig.platformRealtimeWorkerThreadCount =
      canUsePlatformRealtimeThreading(preparedConfig) ? preparedConfig.activeWorkerThreadCount : 0;

  return preparedConfig;
}

bool threadConfigsMatch(
    const GraphExecutor::ThreadConfig& a, const GraphExecutor::ThreadConfig& b) {
  auto matches = a.audioBlockSize == b.audioBlockSize && a.sampleRate == b.sampleRate &&
                 a.maxActiveWorkerThreadCount == b.maxActiveWorkerThreadCount &&
                 a.activeWorkerThreadCount == b.activeWorkerThreadCount &&
                 a.platformRealtimeWorkerThreadCount == b.platformRealtimeWorkerThreadCount;

#if JUCE_MAC
  matches = matches && a.macAudioWorkgroup == b.macAudioWorkgroup;
#endif

  return matches;
}

// This is a ring buffer, but it has a dynamic size so that it can be sized to
// the total node count. Our standard ring buffer has a compile-time size.
class RuntimeReadyNodeQueue {
public:
  explicit RuntimeReadyNodeQueue(size_t capacity)
    : fifo(static_cast<int>(capacity + 1)), buffer(capacity + 1, nullptr) {
    jassert(capacity < static_cast<size_t>(std::numeric_limits<int>::max()));
  }

  RuntimeReadyNodeQueue(const RuntimeReadyNodeQueue&) = delete;
  RuntimeReadyNodeQueue& operator=(const RuntimeReadyNodeQueue&) = delete;

  RuntimeReadyNodeQueue(RuntimeReadyNodeQueue&&) = delete;
  RuntimeReadyNodeQueue& operator=(RuntimeReadyNodeQueue&&) = delete;

  bool add(RuntimeNode* node) {
    int start1 = 0;
    int size1 = 0;
    int start2 = 0;
    int size2 = 0;
    fifo.prepareToWrite(1, start1, size1, start2, size2);

    if (size1 <= 0) {
      return false;
    }

    buffer[static_cast<size_t>(start1)] = node;
    fifo.finishedWrite(1);
    return true;
  }

  std::optional<RuntimeNode*> read() {
    int start1 = 0;
    int size1 = 0;
    int start2 = 0;
    int size2 = 0;
    fifo.prepareToRead(1, start1, size1, start2, size2);

    if (size1 <= 0) {
      return std::nullopt;
    }

    auto* node = buffer[static_cast<size_t>(start1)];
    fifo.finishedRead(1);
    return node;
  }

  void clear() {
    while (read().has_value()) {
    }
  }
private:
  juce::AbstractFifo fifo;
  std::vector<RuntimeNode*> buffer;
};

} // namespace

class GraphExecutor::RuntimeState::Impl final {
public:
  Impl(size_t queueCount, size_t queueCapacity) {
    readyNodeQueues.reserve(queueCount);

    for (size_t queueIndex = 0; queueIndex < queueCount; ++queueIndex) {
      readyNodeQueues.push_back(std::make_unique<RuntimeReadyNodeQueue>(queueCapacity));
    }
  }

  std::vector<std::unique_ptr<RuntimeReadyNodeQueue>> readyNodeQueues;
};

class GraphExecutor::Impl final {
public:
  Impl() = default;

  ~Impl() {
    stopWorkerThreads();
  }

  void prepare(const GraphExecutor::ThreadConfig& threadConfig) {
    availableCoreCount = getAvailableCoreCount();
    const auto targetWorkerThreadCount = getWorkerThreadCountForCoreCount(availableCoreCount);
    auto targetThreadConfig = buildPreparedThreadConfig(targetWorkerThreadCount, threadConfig);

    if (static_cast<int>(workerThreads.size()) == targetWorkerThreadCount &&
        threadConfigsMatch(currentThreadConfig, targetThreadConfig)) {
      return;
    }

    stopWorkerThreads();
    currentThreadConfig = targetThreadConfig;
    workerThreads.reserve(static_cast<size_t>(targetWorkerThreadCount));

    for (int workerIndex = 0; workerIndex < targetWorkerThreadCount; ++workerIndex) {
      auto workerThread = std::make_unique<GraphWorkerThread>(*this, workerIndex, currentThreadConfig);

      if (!workerThread->start()) {
        jassertfalse;
        break;
      }

      workerThreads.push_back(std::move(workerThread));
    }
  }

  size_t getReadyNodeQueueCount() const {
    return workerThreads.size() + 1;
  }

  void rt_processBlock(RuntimeGraph& runtimeGraph, RuntimeState& runtimeState, int numSamples) {
    GraphExecutorState state(runtimeGraph);
    rt_prepareGraphForBlock(state);

    if (runtimeGraph.nodes.empty()) {
      return;
    }

    jassert(!runtimeGraph.outputNodes.empty());
    if (runtimeGraph.outputNodes.empty()) {
      return;
    }

    rt_prepareQueuesForBlock(runtimeGraph, runtimeState);

    rt_currentState.store(&state, std::memory_order_release);
    rt_currentRuntimeState.store(&runtimeState, std::memory_order_release);
    rt_currentNumSamples.store(numSamples, std::memory_order_release);
    rt_workerThreadsMayRun.store(true, std::memory_order_release);

    rt_doWork(state,
        runtimeState,
        ExecutorThreadRole::audioThread,
        audioThreadReadyQueueIndex,
        numSamples);

    rt_workerThreadsMayRun.store(false, std::memory_order_release);
    rt_currentRuntimeState.store(nullptr, std::memory_order_release);
    rt_currentState.store(nullptr, std::memory_order_release);

    rt_waitForActiveWorkerThreadsToFinish();
  }
private:
  class GraphWorkerThread final : public juce::Thread {
  public:
    GraphWorkerThread(Impl& owner,
        int workerIndex,
        const GraphExecutor::ThreadConfig& threadConfig)
      : juce::Thread("Anthem Graph Worker " + juce::String(workerIndex)), owner(owner),
        threadConfig(threadConfig), index(workerIndex),
        readyQueueIndex(static_cast<size_t>(workerIndex) + 1) {}

    ~GraphWorkerThread() override {
      stop();
    }

    bool start() {
      return startGraphExecutorWorkerThread(*this, index, threadConfig);
    }

    void stop() {
      signalThreadShouldExit();
      notify();
      stopThread(threadStopTimeoutMs);
    }

    bool tryWake() {
      bool expected = true;

      if (!isSleeping.compare_exchange_strong(
              expected, false, std::memory_order_acq_rel, std::memory_order_acquire)) {
        return false;
      }

      notify();
      return true;
    }

    void run() override {
      [[maybe_unused]] GraphExecutorWorkerThreadStartupScope startup(
          index, getThreadName(), threadConfig);

      while (!threadShouldExit()) {
        isSleeping.store(true, std::memory_order_release);
        wait(-1.0);
        isSleeping.store(false, std::memory_order_release);

        if (threadShouldExit()) {
          break;
        }

        owner.rt_doWorkerWork(index, readyQueueIndex);
      }
    }
  private:
    Impl& owner;
    GraphExecutor::ThreadConfig threadConfig;
    int index;
    size_t readyQueueIndex;
    std::atomic<bool> isSleeping{false};
  };

  void stopWorkerThreads() {
    for (auto& workerThread : workerThreads) {
      workerThread->stop();
    }

    workerThreads.clear();
  }

  void rt_prepareQueuesForBlock(RuntimeGraph& runtimeGraph, RuntimeState& runtimeState) {
    auto& readyNodeQueues = runtimeState.impl->readyNodeQueues;

    jassert(readyNodeQueues.size() == getReadyNodeQueueCount());
    jassert(runtimeGraph.availableTasks.empty());

    for (auto& readyNodeQueue : readyNodeQueues) {
      readyNodeQueue->clear();
    }

    if (readyNodeQueues.empty()) {
      return;
    }

    for (auto* inputNode : runtimeGraph.inputNodes) {
      if (inputNode->isOutputNode) {
        continue;
      }

      if (!readyNodeQueues[audioThreadReadyQueueIndex]->add(inputNode)) {
        jassertfalse;
      }
    }
  }

  bool rt_isWorkerThreadActive(int workerIndex) const {
    return workerIndex >= 0 &&
           static_cast<size_t>(workerIndex) < currentThreadConfig.activeWorkerThreadCount;
  }

  void rt_doWorkerWork(int workerIndex, size_t readyQueueIndex) {
    if (!rt_isWorkerThreadActive(workerIndex)) {
      return;
    }

    rt_activeWorkerThreadCount.fetch_add(1, std::memory_order_acq_rel);
    const juce::ScopeGuard activeWorkerThreadScope{
        [this]() { rt_activeWorkerThreadCount.fetch_sub(1, std::memory_order_acq_rel); }};

    if (!rt_workerThreadsMayRun.load(std::memory_order_acquire)) {
      return;
    }

    auto* state = rt_currentState.load(std::memory_order_acquire);
    auto* runtimeState = rt_currentRuntimeState.load(std::memory_order_acquire);

    if (state == nullptr || runtimeState == nullptr) {
      return;
    }

    const auto numSamples = rt_currentNumSamples.load(std::memory_order_acquire);
    rt_doWork(*state, *runtimeState, ExecutorThreadRole::workerThread, readyQueueIndex, numSamples);
  }

  void rt_waitForActiveWorkerThreadsToFinish() {
    while (rt_activeWorkerThreadCount.load(std::memory_order_acquire) > 0) {
      spin_pause();
    }

    jassert(rt_activeWorkerThreadCount.load(std::memory_order_acquire) == 0);
  }

  void rt_doWork(GraphExecutorState& state,
      RuntimeState& runtimeState,
      ExecutorThreadRole role,
      size_t readyQueueIndex,
      int numSamples) {
    while (true) {
      auto* runtimeNode = rt_getNextNodeToProcess(state.runtimeGraph, runtimeState, role);

      if (runtimeNode == nullptr) {
        if (role == ExecutorThreadRole::workerThread) {
          return;
        }

        if (rt_canProcessOutputNodes(state.runtimeGraph)) {
          rt_processOutputNodes(state, numSamples);
          return;
        }

        spin_pause();
        continue;
      }

      jassert(role == ExecutorThreadRole::audioThread || !runtimeNode->isOutputNode);

      rt_processNode(state, *runtimeNode, numSamples);
      rt_enqueueReadyDownstreamNodes(*runtimeNode, runtimeState, readyQueueIndex);
    }
  }

  RuntimeNode* rt_getNextNodeToProcess(
      RuntimeGraph& runtimeGraph, RuntimeState& runtimeState, ExecutorThreadRole role) {
    if (!rt_acquireSchedulerGate(role)) {
      return nullptr;
    }

    rt_drainReadyNodeQueues(runtimeGraph, runtimeState);
    auto* nextNode = rt_popNextAvailableNode(runtimeGraph, role);
    rt_wakeWorkerBeforeReleasingSchedulerGate(runtimeGraph);
    rt_releaseSchedulerGate();

    return nextNode;
  }

  bool rt_acquireSchedulerGate(ExecutorThreadRole role) {
    if (role == ExecutorThreadRole::audioThread) {
      audioThreadWaitingForSchedulerGate.store(true, std::memory_order_release);

      while (true) {
        bool expected = false;

        if (schedulerGate.compare_exchange_weak(
                expected, true, std::memory_order_acq_rel, std::memory_order_acquire)) {
          audioThreadWaitingForSchedulerGate.store(false, std::memory_order_release);
          return true;
        }

        spin_pause();
      }
    }

    for (int attempt = 0; attempt < workerGateSpinAttempts; ++attempt) {
      if (audioThreadWaitingForSchedulerGate.load(std::memory_order_acquire)) {
        spin_pause();
        continue;
      }

      bool expected = false;

      if (schedulerGate.compare_exchange_weak(
              expected, true, std::memory_order_acq_rel, std::memory_order_acquire)) {
        return true;
      }

      spin_pause();
    }

    return false;
  }

  void rt_releaseSchedulerGate() {
    schedulerGate.store(false, std::memory_order_release);
  }

  // As worker threads complete tasks, they may unlock downstream nodes for
  // processing. Each thread has a ring buffer that it pushes node pointers to
  // when they are unlocked.
  //
  // This method pulls from these buffers and adds to the main task queue.
  //
  // Reading from these ring buffers and reading/writing from/to the main task
  // queue are NOT inherently thread-safe operations, and must be gated by
  // schedulerGate.
  void rt_drainReadyNodeQueues(RuntimeGraph& runtimeGraph, RuntimeState& runtimeState) {
    for (auto& readyNodeQueue : runtimeState.impl->readyNodeQueues) {
      while (auto readyNode = readyNodeQueue->read()) {
        if (readyNode.value() != nullptr) {
          runtimeGraph.availableTasks.push(readyNode.value());
        }
      }
    }
  }

  RuntimeNode* rt_popNextAvailableNode(RuntimeGraph& runtimeGraph, ExecutorThreadRole role) {
    if (runtimeGraph.availableTasks.empty()) {
      return nullptr;
    }

    auto* nextNode = runtimeGraph.availableTasks.top();

    if (role == ExecutorThreadRole::workerThread) {
      if (runtimeGraph.availableTasks.size() < 2) {
        return nullptr;
      }
    }

    jassert(!nextNode->isOutputNode);
    if (nextNode->isOutputNode) {
      return nullptr;
    }

    runtimeGraph.availableTasks.pop();
    return nextNode;
  }

  void rt_enqueueReadyDownstreamNodes(
      RuntimeNode& runtimeNode, RuntimeState& runtimeState, size_t readyQueueIndex) {
    auto& readyNodeQueues = runtimeState.impl->readyNodeQueues;

    jassert(readyQueueIndex < readyNodeQueues.size());

    if (readyQueueIndex >= readyNodeQueues.size()) {
      return;
    }

    auto& readyNodeQueue = *readyNodeQueues[readyQueueIndex];

    for (auto* downstreamNode : runtimeNode.outgoingConnections) {
      if (!rt_decrementRemainingUpstreamNodes(*downstreamNode)) {
        continue;
      }

      if (downstreamNode->isOutputNode) {
        continue;
      }

      if (!readyNodeQueue.add(downstreamNode)) {
        jassertfalse;
      }
    }
  }

  bool rt_canProcessOutputNodes(RuntimeGraph& runtimeGraph) {
    for (auto* outputNode : runtimeGraph.outputNodes) {
      jassert(outputNode != nullptr);

      if (outputNode == nullptr) {
        return false;
      }

      if (outputNode->rt_state.rt_remainingUpstreamNodes.load(std::memory_order_acquire) != 0) {
        return false;
      }
    }

    return true;
  }

  void rt_processOutputNodes(GraphExecutorState& state, int numSamples) {
    for (auto* outputNode : state.runtimeGraph.outputNodes) {
      jassert(outputNode != nullptr);

      if (outputNode != nullptr) {
        rt_processNode(state, *outputNode, numSamples);
      }
    }
  }

  void rt_wakeWorkerBeforeReleasingSchedulerGate(RuntimeGraph& runtimeGraph) {
    if (runtimeGraph.availableTasks.size() < 2) {
      return;
    }

    for (size_t workerIndex = 0; workerIndex < currentThreadConfig.activeWorkerThreadCount &&
                                 workerIndex < workerThreads.size();
         ++workerIndex) {
      auto& workerThread = workerThreads[workerIndex];

      if (workerThread->tryWake()) {
        return;
      }
    }
  }

  int availableCoreCount = minimumCoreCount;
  GraphExecutor::ThreadConfig currentThreadConfig;
  std::vector<std::unique_ptr<GraphWorkerThread>> workerThreads;
  std::atomic<bool> schedulerGate{false};
  std::atomic<bool> audioThreadWaitingForSchedulerGate{false};
  std::atomic<GraphExecutorState*> rt_currentState{nullptr};
  std::atomic<RuntimeState*> rt_currentRuntimeState{nullptr};
  std::atomic<int> rt_currentNumSamples{0};
  std::atomic<bool> rt_workerThreadsMayRun{false};
  std::atomic<int> rt_activeWorkerThreadCount{0};
};

} // namespace anthem
