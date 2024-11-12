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

class AnthemModelBase;

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
public:
  std::weak_ptr<AnthemModelBase> parent;
};
