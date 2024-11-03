/*
  Copyright (C) 2024 Joshua Wade

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

#include "modules/processing_graph/processor/anthem_processor.h"

// The gain node takes an audio input and multiplies each sample by a control
// input.
//
// Note that this control input is a raw gain value, not decibels. Decibels can
// be converted to raw gain using the following formula:
//
// `rawGain = 10 ^ (decibels / 20)`
//
// As an example, -3 db converts to a raw gain of roughly 0.7:
//
// `10 ^ (-0.3 / 20) ~= 0.7`
//
// So, for a decibel change of -3 db, the control value must be roughly 0.7.
//
// The input can be anything from from 0 (-inf db) to 10 (+20 db).
class GainNode : public AnthemProcessor {
public:
  GainNode();
  ~GainNode() override;

  void process(AnthemProcessContext& context, int numSamples) override;
};
