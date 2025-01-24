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

struct ObserverHandle {
  size_t id;
};

// A utility class that holds observers for a single field.
template <typename T>
class FieldObservers {
public:
  ObserverHandle addObserver(std::function<void(const T&)> observer) {
    // Generate a unique ID, store the observer in a map.
    size_t newId = nextId++;
    observers.emplace(newId, std::move(observer));
    return ObserverHandle{newId};
  }

  void removeObserver(ObserverHandle handle) {
    observers.erase(handle.id);
  }

  void notify(const T& value) {
    // Call all observers.
    for (auto& kv : observers) {
      kv.second(value);
    }
  }

private:
  size_t nextId = 0;
  std::unordered_map<size_t, std::function<void(const T&)>> observers;
};
