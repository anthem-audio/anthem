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

#include "linear_parameter_smoother.h"

LinearParameterSmoother::LinearParameterSmoother(float initialValue, float duration) {
  targetValue = initialValue;
  currentValue = initialValue;
  this->duration = duration;
  timeRemaining = 0.0f;
}

void LinearParameterSmoother::setTargetValue(float targetValue) {
  this->targetValue = targetValue;
  timeRemaining = duration;
}

float LinearParameterSmoother::getCurrentValue() {
  return currentValue;
}

float LinearParameterSmoother::getTargetValue() {
  return targetValue;
}

void LinearParameterSmoother::process(float deltaTime) {
  if (timeRemaining > 0.0f) {
    float step = deltaTime / duration;
    currentValue = currentValue + (targetValue - currentValue) * step;
    timeRemaining -= deltaTime;
  } else {
    currentValue = targetValue;
  }
}
