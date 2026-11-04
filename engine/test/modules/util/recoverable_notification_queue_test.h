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

#include "allocation_tracker.h"
#include "modules/util/recoverable_notification_queue.h"

#include <chrono>
#include <juce_core/juce_core.h>
#include <thread>
#include <vector>

namespace anthem {

class RecoverableNotificationQueueTest : public juce::UnitTest {
public:
  RecoverableNotificationQueueTest() : juce::UnitTest("Recoverable notification queue", "Anthem") {}

  void runTest() override {
    beginTest("Records retain order and values across wraparound without allocation");
    RecoverableNotificationQueue<int, 4> buffer;
    for (int round = 0; round < 10; ++round) {
      bool pushed = true;
      {
        test::AllocationScope allocations;
        for (int i = 0; i < 4; ++i)
          pushed &= buffer.tryPush(buffer.currentGeneration(), round * 4 + i);
      }
      expect(pushed);
      expectEquals(test::allocationCount, size_t(0));
      for (int i = 0; i < 4; ++i)
        expectEquals(buffer.tryPop().value_or(-1), round * 4 + i);
      expect(!buffer.tryPop());
    }

    beginTest("Recovery rejects old records and callbacks overlapping the snapshot");
    const auto oldGeneration = buffer.currentGeneration();
    for (int i = 0; i < 4; ++i)
      expect(buffer.tryPush(oldGeneration, i));
    expect(!buffer.tryPush(oldGeneration, 4));
    expect(buffer.takeRecoveryRequest());
    buffer.beginRecovery();
    const auto duringRecovery = buffer.currentGeneration();
    expect(!buffer.tryPush(duringRecovery, 5));
    expect(!buffer.tryPop());
    buffer.endRecovery();
    expect(!buffer.tryPush(oldGeneration, 6));
    expect(!buffer.tryPush(duringRecovery, 7));
    expect(buffer.takeRecoveryRequest());
    expect(buffer.tryPush(buffer.currentGeneration(), 8));
    expectEquals(buffer.tryPop().value_or(-1), 8);

    beginTest("Observing a stale publication requests a fresh authoritative snapshot");
    RecoverableNotificationQueue<int, 4> stale;
    expect(stale.tryPush(stale.currentGeneration(), 1));
    stale.beginRecovery();
    stale.endRecovery();
    expect(!stale.takeRecoveryRequest());
    expect(!stale.tryPop());
    expect(stale.takeRecoveryRequest());

    beginTest("A busy writer requests recovery immediately without allocating");
    RecoverableNotificationQueue<int, 4> busy;
    expect(!busy.writer.test_and_set());
    bool accepted;
    {
      test::AllocationScope allocations;
      accepted = busy.tryPush(busy.currentGeneration(), 1);
    }
    expect(!accepted);
    expectEquals(test::allocationCount, size_t(0));
    expectEquals(test::deallocationCount, size_t(0));
    expect(busy.takeRecoveryRequest());
    busy.writer.clear();
    expect(busy.tryPush(busy.currentGeneration(), 2));
    expectEquals(busy.tryPop().value_or(-1), 2);

    testConcurrentProducers();
  }

  void testConcurrentProducers() {
    beginTest("Concurrent producers preserve each producer's order without corrupting records");
    struct Value {
      int producer;
      int sequence;
    };
    constexpr int producerCount = 4;
    constexpr int perProducer = 10000;
    RecoverableNotificationQueue<Value, 128> buffer;
    std::atomic<int> done{0};
    std::atomic<bool> stop{false};
    std::vector<std::thread> producers;
    for (int producer = 0; producer < producerCount; ++producer) {
      producers.emplace_back([&, producer]() {
        for (int sequence = 0; sequence < perProducer && !stop.load(); ++sequence) {
          // Retrying belongs to this stress test, never to a real-time callback.
          while (!buffer.tryPush(buffer.currentGeneration(), {producer, sequence}) && !stop.load())
            std::this_thread::yield();
        }
        ++done;
      });
    }
    std::array<int, producerCount> next{};
    bool ordered = true;
    int received = 0;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(20);
    while (received < producerCount * perProducer && std::chrono::steady_clock::now() < deadline) {
      if (const auto value = buffer.tryPop()) {
        if (value->producer < 0 || value->producer >= producerCount) {
          ordered = false;
          break;
        }
        ordered &= value->sequence == next[static_cast<size_t>(value->producer)]++;
        ++received;
      } else {
        std::this_thread::yield();
      }
    }
    stop = true;
    for (auto& producer : producers)
      producer.join();
    expect(ordered);
    expectEquals(received, producerCount * perProducer);
    expectEquals(done.load(), producerCount);
  }
};

inline RecoverableNotificationQueueTest recoverableNotificationQueueTest;

} // namespace anthem
