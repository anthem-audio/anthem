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

#include "generated/lib/model/sequencer.h"

class Sequencer : public SequencerModelBase {
public:
  Sequencer(const SequencerModelImpl& _impl) : SequencerModelBase(_impl) {}
  ~Sequencer() {}

  Sequencer(const Sequencer&) = delete;
  Sequencer& operator=(const Sequencer&) = delete;
  
  Sequencer(Sequencer&&) noexcept = default;
  Sequencer& operator=(Sequencer&&) noexcept = default;

  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override;

  // void handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex) {
  //   SequencerModelBase::handleModelUpdate(request, fieldAccessIndex);
  // }
};
