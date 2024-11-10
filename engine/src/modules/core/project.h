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

class Project : public ProjectModelBase {
public:
  Project() : ProjectModelBase() {}
  Project(const ProjectModelImpl& _impl) : ProjectModelBase(_impl) {std::cout << "Project created" << std::endl; this->test();}
  ~Project() {}

  void test() {
    std::cout << "Project test - id: " << this->id() << std::endl;
  }

  // void handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex) {
  //   ProjectModelBase::handleModelUpdate(request, fieldAccessIndex);
  // }
};
