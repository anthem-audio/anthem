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

#include <atomic>
#include <cstdint>
#include <juce_core/juce_core.h>
#include <memory>
#include <optional>
#include <string>

namespace anthem {

class AudioBlockProcessor;
class AudioSessionController;
class Comms;
enum class RenderAudioFormat;
class Transport;

struct RenderStartResult {
  bool success = false;
  std::optional<std::string> error = std::nullopt;
};

class RenderController {
private:
  struct RenderJob;
  class RenderThread;

  AudioSessionController& audioSessionController;
  AudioBlockProcessor& audioBlockProcessor;
  Transport& transport;
  Comms& comms;

  std::atomic_bool isRenderingFlag{false};
  juce::CriticalSection renderThreadMutex;
  std::unique_ptr<RenderThread> renderThread;

  void sendRenderStartedEvent(int64_t renderId, int64_t totalSamples);
  void sendRenderProgressEvent(int64_t renderId, int64_t renderedSamples, int64_t totalSamples);
  void sendRenderCompletedEvent(int64_t renderId, int64_t renderedSamples, int64_t totalSamples);
  void sendRenderFailedEvent(
      int64_t renderId, const std::string& error, int64_t renderedSamples, int64_t totalSamples);
  void runRender(RenderJob renderJob, RenderThread& thread);
  void finishRenderThreadState();
public:
  RenderController(AudioSessionController& audioSessionController,
      AudioBlockProcessor& audioBlockProcessor,
      Transport& transport,
      Comms& comms);
  ~RenderController();

  RenderStartResult startRender(int64_t renderId,
      const std::string& outputPath,
      RenderAudioFormat format,
      int64_t startTick,
      int64_t endTick,
      bool includeTail);
  void stopRenderThread();

  bool isRendering() const {
    return isRenderingFlag.load(std::memory_order_acquire);
  }
};

} // namespace anthem
