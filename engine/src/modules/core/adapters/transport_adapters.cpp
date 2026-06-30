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

#include "transport_adapters.h"

#include "modules/core/engine.h"

namespace anthem {

namespace {
std::optional<LoopPointsSnapshot> snapshotFromLoopPoints(
    const std::optional<std::shared_ptr<LoopPointsModel>>& loopPoints) {
  if (!loopPoints.has_value() || loopPoints.value() == nullptr) {
    return std::nullopt;
  }

  return LoopPointsSnapshot{
      .start = static_cast<double>(loopPoints.value()->start()),
      .end = static_cast<double>(loopPoints.value()->end()),
  };
}

class EngineTransportProjectView : public TransportProjectView {
private:
  Engine& engine;
public:
  explicit EngineTransportProjectView(Engine& engine) : engine(engine) {}

  std::optional<LoopPointsSnapshot> lookupLoopPoints(int64_t sequenceId) const override {
    if (engine.project == nullptr) {
      return std::nullopt;
    }

    auto& sequence = *engine.project->sequence();
    auto& patterns = *sequence.patterns();
    auto& arrangements = *sequence.arrangements();

    if (auto patternIt = patterns.find(sequenceId); patternIt != patterns.end()) {
      if (auto snapshot = snapshotFromLoopPoints(patternIt->second->loopPoints())) {
        return snapshot;
      }
    }

    if (auto arrangementIt = arrangements.find(sequenceId); arrangementIt != arrangements.end()) {
      return snapshotFromLoopPoints(arrangementIt->second->loopPoints());
    }

    return std::nullopt;
  }

  bool isPatternSequence(int64_t sequenceId) const override {
    if (engine.project == nullptr) {
      return false;
    }

    auto& patterns = *engine.project->sequence()->patterns();
    return patterns.find(sequenceId) != patterns.end();
  }

  const SequenceEventListCollection* compiledSequence(int64_t sequenceId) const override {
    if (engine.sequenceStore == nullptr) {
      return nullptr;
    }

    return engine.sequenceStore->getSequenceEventList(sequenceId);
  }
};

class EngineTransportClock : public TransportClock {
private:
  Engine& engine;
public:
  explicit EngineTransportClock(Engine& engine) : engine(engine) {}

  double currentSampleRate() const override {
    if (engine.audioSessionController == nullptr) {
      return 0.0;
    }

    auto audioProcessingConfig = engine.audioSessionController->getCurrentAudioProcessingConfig();
    jassert(audioProcessingConfig.has_value());
    if (!audioProcessingConfig.has_value()) {
      return 0.0;
    }

    return audioProcessingConfig->sampleRate;
  }
};
} // namespace

std::unique_ptr<TransportProjectView> createTransportProjectView(Engine& engine) {
  return std::make_unique<EngineTransportProjectView>(engine);
}

std::unique_ptr<TransportClock> createTransportClock(Engine& engine) {
  return std::make_unique<EngineTransportClock>(engine);
}

} // namespace anthem
