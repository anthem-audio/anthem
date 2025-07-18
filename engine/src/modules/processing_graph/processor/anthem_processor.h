/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

#include <string>
#include <memory>

#include <juce_core/juce_core.h>

class AnthemGraphNode;
class AnthemProcessContext;

// This class is used to process audio, event and control data. It can produce
// and/or consume any of these data types.
//
// This serves as a base class for internal and external plugins, but also for
// several internal processing modules that interact with the processing graph.
class AnthemProcessor {
public:
  // The name of the processor.
  std::string name;

  AnthemProcessor(std::string name) : name(name) {}

  virtual ~AnthemProcessor() = default;

  // Called on the JUCE message thread to initialize the processor.
  //
  // Note that this is called after the audio device is started, so audio device
  // information can be queried at this point.
  virtual void prepareToProcess() = 0;

  // This flag must be set after prepareToProcess() is called. It is set by the
  // caller, not by the processor itself.
  bool isPrepared = false;

  // This method is called by the processing graph to process audio, event and
  // control data. It is called once per processing block.
  virtual void process(AnthemProcessContext& context, int numSamples) = 0;

  // Gets the state of the processor
  virtual void getState(juce::MemoryBlock& target) {}

  // Loads the state of the processor from a value exported by getState()
  virtual void setState(const juce::MemoryBlock& state) {}
};
