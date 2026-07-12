/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#include "generated/lib/model/processing_graph/processors/balance.h"
#include "modules/processing_graph/processor/processor.h"

// A balance processor.
namespace anthem {

class BalanceProcessor : public Processor, public BalanceProcessorModelBase {
private:
public:
  BalanceProcessor(const BalanceProcessorModelImpl& _impl);
  ~BalanceProcessor() override;

  BalanceProcessor(const BalanceProcessor&) = delete;
  BalanceProcessor& operator=(const BalanceProcessor&) = delete;

  BalanceProcessor(BalanceProcessor&&) noexcept = default;
  BalanceProcessor& operator=(BalanceProcessor&&) noexcept = default;

  void prepareToProcess(ProcessorPrepareCallback complete) override;
  void process(NodeProcessContext& context, int numSamples) override;
};

} // namespace anthem
