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

#include <juce_core/juce_core.h>
#include <optional>

template <typename T>
class ThreadSafeQueue
{
public:
  ThreadSafeQueue(int size) : fifo(size), buffer(size) {}

  // Adds an item to the queue from the main thread
  void add(T item) {
    int start1, size1, start2, size2;
    fifo.prepareToWrite(1, start1, size1, start2, size2);

    if (size1 > 0) {
      buffer[start1] = item;
      fifo.finishedWrite(1);
    }
  }

  // Reads the next item from the queue if it exists
  std::optional<T> read()
  {
    int start1, size1, start2, size2;
    fifo.prepareToRead(1, start1, size1, start2, size2);

    if (size1 > 0) {
      T item = buffer[start1];
      fifo.finishedRead(1);
      return item;
    }

    return std::nullopt;
  }

private:
  juce::AbstractFifo fifo;
  std::vector<T> buffer;
};
