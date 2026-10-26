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

#include "file_storage_client.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/processor/processor.h"

namespace anthem {

// Captures and restores opaque processor state through the project file store.
// Calls and completions run on the message thread, never the audio thread.
class ProcessorStateStorage {
public:
  explicit ProcessorStateStorage(FileStorageClient& files) : files(files) {}

  // Returns the previous path if the captured bytes are unchanged. An empty
  // path means the processor supplied no opaque state.
  void capture(
      const std::shared_ptr<Node>& node, FileStorageClient::RelativePathCompletion complete);
  void restore(const std::shared_ptr<Node>& node,
      const std::shared_ptr<Processor>& processor,
      FileStorageClient::Completion complete);
private:
  FileStorageClient& files;
};

} // namespace anthem
