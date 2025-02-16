/*
  Copyright (C) 2025 Joshua Wade

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

#include <atomic>
#include <optional>
#include <juce_events/juce_events.h>

// This is a value that can be sent from the main thread to the audio thread.
//
// It is used when the latest value is the only relevant value. If you need to
// be able to read through all the values that have been sent, then you should
// use a ThreadSafeQueue instead.
//
// This operates like a mutexed value. The real-time code can lock the value via
// a fence created with an atomic value. The difference is that, if the main
// thread is locked out of writing at any given time, then the main thread will
// schedule async work to retry the write until it succeeds.
//
// A couple assumptions are made here:
//
// 1. The audio thread will regularly check this value for updates, e.g. at the
//    start of every processing block
// 2. It is okay for the audio thread to only receive the latest value, and to
//    possibly miss some values if the main thread is writing faster than the
//    audio thread can read.
//
// If either of these assumptions is not true, then this class is not suitable.
//
// Note that, to use this class safely, T MUST BE TRIVIALLY COPYABLE. There
// cannot be any operations in the copy or move constructors for T that could
// block or otherwise would not be real-time safe.
template <typename T>
class DoubleBufferedValue {
private:
  // If true, then mutations to fields in this class are not allowed.
  //
  // This is used to prevent either thread from trying to mutate when the other
  // thread is mutating. This can never prevent the audio thread from reading,
  // but the audio thread will set this when it is updating its read target.
  std::atomic<bool> locked = false;

  // Either thread can use this to acquire a mutation lock.
  bool tryLock() {
    bool expected = false;
    return locked.compare_exchange_strong(expected, true, std::memory_order_acquire);
  }

  // Either thread can use this to release a mutation lock.
  void unlock() {
    locked.store(false, std::memory_order_release);
  }

  // If true, then there is a newer value in the other read target.
  bool isReadTargetStale = false;

  // The read target. False = A, true = B.
  bool readTarget = false;

  // Value A
  T valueA;

  // Value B
  T valueB;

  // A pending write value, used if the first write fails.
  std::optional<T> pendingWrite;

  // The current delay in ms before the next backoff attempt.
  int backoffDelayMs = 1;

  bool trySet(T value) {
    if (tryLock()) {
      if (readTarget) {
        valueB = value;
      } else {
        valueA = value;
      }
      isReadTargetStale = true;
      unlock();

      return true;
    }

    return false;
  }

  void scheduleBackoffAttempt() {
    // Use Timer::callAfterDelay to schedule a one-shot callback on the message thread.
    juce::Timer::callAfterDelay(backoffDelayMs, [this]() {
      // Attempt to write whatever is currently pending.
      attemptPendingWrite();
    });
  }

  void attemptPendingWrite() {
    // Try the write again:
    if (trySet(*pendingWrite)) {
      // Success: clear the pending value, reset the state
      pendingWrite.reset();
      backoffDelayMs = 1;
    } else {
      // Still locked. Double the delay:
      backoffDelayMs = juce::jmin(backoffDelayMs * 2, 2000); // Cap at 2s

      // Schedule the next retry
      scheduleBackoffAttempt();
    }
  }

public:
  // Gets the latest value.
  //
  // A newer value may exist in the inactive target. In this case, rt_get() will
  // udpate the active target and read the latest value.
  //
  // If the other thread is currently mutating the non-active value, then this
  // method will load the stale value.
  T rt_get() {
    if (tryLock()) {
      if (isReadTargetStale) {
        readTarget = !readTarget;
        isReadTargetStale = false;
      }
      unlock();
    }

    if (readTarget) {
      return valueB;
    } else {
      return valueA;
    }
  }

  // Sets the value.
  //
  // If the audio thread is currently reading, then this will schedule async work
  // to retry the write until it succeeds.
  void set(T value) {
    // If we already hae a pending write, then there is an active retry backoff
    // happening. In this case, we can just update the pending write value.
    if (pendingWrite.has_value()) {
      pendingWrite = value;
      return;
    }
    
    bool success = trySet(value);
    if (success) return;

    // If we get here, then the audio thread is currently reading. In this case,
    // we need to schedule async work to retry the write until it succeeds.
    pendingWrite = value;
    
    // Schedule the first retry
    scheduleBackoffAttempt();
  }
};
