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

#include <memory>
#include <unordered_map>
#include <functional>
#include <optional>

class AnthemModelBase;

// Specifies a set of filters on model changes.
struct AnthemModelChangeFilter {
  std::optional<std::string> fieldName;

  // We can add more things here if needed, like collection change filters, etc.
  //
  // For now, we can do two things:
  //   - Filter by field name, which is specified here
  //   - Trigger behavior on model constructor and destructor
  //
  // In the future, we may want to, for example, observe a list of integers. In
  // this case, we can't just add behavior to an element constructor because the
  // element is a primitive, so we'll need to add behavior here to allow for
  // observing the list itself.
};

// Base class used for all generated model classes.
//
// This class is used to provide a common set of functionality for all model
// classes. It defines behavior for tracking parent models, and for model change
// observability.
//
// This class is not intended to be used directly, but rather to be inherited by
// generated model classes, and anything else that is part of the model tree (e.g.
// collection wrappers).
class AnthemModelBase {
private:
  uint64_t nextObserverId = 0;

  // The set of observers that are listening for changes to this model.
  std::unordered_map<
    uint64_t,
    std::tuple<std::optional<AnthemModelChangeFilter>, std::function<void()>>
  > observers;

public:
  // Default empty constructor
  AnthemModelBase() = default;

  // Delete copy constructors
  AnthemModelBase(const AnthemModelBase&) = delete;
  AnthemModelBase& operator=(const AnthemModelBase&) = delete;

  // Default move constructors
  AnthemModelBase(AnthemModelBase&&) noexcept = default;
  AnthemModelBase& operator=(AnthemModelBase&&) noexcept = default;

  // The parent of this model.
  std::weak_ptr<AnthemModelBase> parent;

  // This model.
  std::weak_ptr<AnthemModelBase> self;

  virtual void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) {
    this->self = self;
    this->parent = parent;
  }

  // Adds an observer to this model.
  uint64_t addObserver(AnthemModelChangeFilter filter, std::function<void()> observer) {
    auto id = nextObserverId++;
    observers[id] = std::make_tuple(filter, observer);
    return id;
  }

  uint64_t addObserver(std::string fieldName, std::function<void()> observer) {
    return addObserver(AnthemModelChangeFilter{.fieldName = std::optional(fieldName)}, observer);
  }

  // Removes an observer from this model.
  void removeObserver(uint64_t observerId) {
    observers.erase(observerId);
  }

  // Processes a change to this model.
  void processChange(std::string fieldName) {
    for (auto& [_, observerTuple] : observers) {
      auto [filter, observer] = observerTuple;

      if (!filter.has_value() || !filter->fieldName.has_value() || filter->fieldName.value() == fieldName) {
        observer();
      }
    }
  }
};
