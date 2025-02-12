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

#include "generated/lib/model/sequence.h"

class Sequence : public SequenceModelBase {
public:
  Sequence(const SequenceModelImpl& _impl) : SequenceModelBase(_impl) {}
  ~Sequence() {}

  Sequence(const Sequence&) = delete;
  Sequence& operator=(const Sequence&) = delete;
  
  Sequence(Sequence&&) noexcept = default;
  Sequence& operator=(Sequence&&) noexcept = default;

  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override {
    SequenceModelBase::initialize(self, parent);
  }

  // void handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex) {
  //   SequenceModelBase::handleModelUpdate(request, fieldAccessIndex);
  // }
};
