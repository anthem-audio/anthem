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

#include "modules/core/audio_processing_config.h"

#include <atomic>
#include <cstdint>
#include <functional>
#include <juce_audio_devices/juce_audio_devices.h>
#include <memory>
#include <mutex>
#include <optional>
#include <string>

namespace anthem {

class AudioBlockProcessor;
class AudioCallback;
class Comms;
class GraphProcessor;
enum class GraphWorkerSchedulingMode;
class Project;
class Transport;

struct AudioProcessingConfigSnapshot {
  AudioProcessingConfig config;
  uint64_t generation;
};

class AudioSessionController {
private:
  std::shared_ptr<Project>& project;
  GraphProcessor& graphProcessor;
  Transport& transport;
  Comms& comms;
  AudioBlockProcessor& audioBlockProcessor;
  std::function<void()> resetInitializedProcessingGraphNodes;

  std::atomic_bool isRealtimeAudioRunningFlag{false};
  bool isRenderAudioSessionActive = false;

  juce::AudioDeviceManager audioDeviceManager;
  std::unique_ptr<AudioCallback> audioCallback;

  // This mutex is used because audioDeviceAboutToStart may be called by JUCE on
  // a different thread besides the message thread. Because we need to check the
  // config in this case, we need thread safety here.
  mutable std::mutex audioProcessingConfigMutex;
  std::optional<AudioProcessingConfig> currentAudioProcessingConfig;

  // A runtime node graph is only valid for the config that it was created with.
  // If the config changes, then the audio thread needs a way to tell.
  //
  // We do this by sending a "generation" number to the audio thread along with
  // the config. It then compares with this atomic value. If this value changes
  // before the graph has been rebuilt, then the audio thread will short-circuit
  // and render silence until the graph is rebuilt with an updated config.
  std::atomic<uint64_t> audioProcessingConfigGeneration{0};

  uint64_t setCurrentAudioProcessingConfig(AudioProcessingConfig audioProcessingConfig);
  void clearCurrentAudioProcessingConfig();
  void prepareForAudioProcessingConfig(const AudioProcessingConfig& audioProcessingConfig,
      GraphWorkerSchedulingMode workerSchedulingMode);
  void sendAudioSessionInvalidatedEvent(std::optional<std::string> reason);
  void notifyAudioSessionInvalidatedOnMessageThread(
      std::optional<std::string> reason, uint64_t invalidatedGeneration);
  std::optional<AudioProcessingConfig> refreshAudioProcessingConfigForDevice(
      juce::AudioIODevice& device);
public:
  AudioSessionController(std::shared_ptr<Project>& project,
      GraphProcessor& graphProcessor,
      Transport& transport,
      Comms& comms,
      AudioBlockProcessor& audioBlockProcessor,
      std::function<void()> resetInitializedProcessingGraphNodes);
  ~AudioSessionController();

  std::optional<AudioProcessingConfig> startRealtimeAudio();
  std::optional<AudioProcessingConfig> startRenderAudioSession(
      double sampleRate, int64_t blockSize, int64_t outputChannelCount);
  void stopAudio();
  void requestAudioSessionInvalidation(std::optional<std::string> reason);

  bool isRealtimeAudioRunning() const {
    return isRealtimeAudioRunningFlag.load(std::memory_order_acquire);
  }

  bool hasActiveAudioSession() const {
    return isRealtimeAudioRunning() || isRenderAudioSessionActive;
  }

  bool isRenderAudioSessionRunning() const {
    return isRenderAudioSessionActive;
  }

  std::optional<AudioProcessingConfig> getCurrentAudioProcessingConfig() const;
  std::optional<AudioProcessingConfigSnapshot> getCurrentAudioProcessingConfigSnapshot() const;
  uint64_t getAudioProcessingConfigGeneration() const;
};

} // namespace anthem
