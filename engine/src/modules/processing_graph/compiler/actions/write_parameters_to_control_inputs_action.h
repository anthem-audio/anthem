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

#include <memory>

#include "anthem_graph_compiler_action.h"
#include "anthem_process_context.h"

class WriteParametersToControlInputsAction : public AnthemGraphCompilerAction {
private:
  std::shared_ptr<AnthemProcessContext> processContext;
  float sampleRate;
public:
  WriteParametersToControlInputsAction(std::shared_ptr<AnthemProcessContext> processContext, float sampleRate)
    : processContext(processContext), sampleRate(sampleRate) {}

  void execute(int numSamples) override;

  void debugPrint() override;
};
