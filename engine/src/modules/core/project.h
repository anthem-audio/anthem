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

#include "generated/lib/model/project.h"
#include "song.h"

class Project : public ProjectModelBase {
public:
  Project(const ProjectModelImpl& _impl) : ProjectModelBase(_impl) {}
  ~Project() {}

  Project(const Project&) = delete;
  Project& operator=(const Project&) = delete;
  
  Project(Project&&) noexcept = default;
  Project& operator=(Project&&) noexcept = default;

  // void handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex) {
  //   ProjectModelBase::handleModelUpdate(request, fieldAccessIndex);
  // }
};
