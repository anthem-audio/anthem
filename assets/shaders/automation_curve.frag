/*
  Copyright (C) 2023 Joshua Wade

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

#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 resolution;

// FlutterFragCoord() is relative to the top-left of the canvas. This shader
// pass represents a single curve, and will likely have an offset from the
// top-left of the canvas. The uniform below uniform encodes this offset.
uniform vec2 offset;

uniform float lastPointTime;
uniform float lastPointY;
uniform float thisPointTime;
uniform float thisPointY;
uniform float tension;

out vec4 fragColor;

const float linearCenterTransitionRate = 0.27;
const float linearCenterWidth = 1.6;
const float pi = 3.1415926538;

// Curve functions

float g(float x) {
  return atan(x * linearCenterTransitionRate * pi) / pi + 0.5;
}

float getLinearCenterInterpolation(float tension) {
  return 1 -
      (g(tension + linearCenterWidth) +
          (1 - g(tension - linearCenterWidth)) -
          1);
}

float getRawTensionForSmooth(float tension) {
  float linearCenterInterpolation = getLinearCenterInterpolation(tension);

  return pow(tension / 2.0, 2.2) * linearCenterInterpolation +
      0.7 * tension * (1 - linearCenterInterpolation);
}

float smoothCurve(float normalizedX, float tension) {
  float rawTension = getRawTensionForSmooth(tension * 10);
  if (tension >= 0) {
    return pow(normalizedX, rawTension + 1);
  } else {
    return 1 - pow(1 - normalizedX, -rawTension + 1);
  }
}

void main() {
  vec2 st = (FlutterFragCoord().xy - offset) / resolution.xy;

  vec4 targetColor = vec4(0.0, 0.5, 0.5, 1.0);

  float normalizedX = st.x;
  float rawCurveY = smoothCurve(normalizedX, tension);
  float curveY = rawCurveY * (thisPointY - lastPointY) + lastPointY;

  if (abs(curveY - (1-st.y)) < 2.0 / resolution.y) {
    fragColor = targetColor;
  } else {
    fragColor = vec4(0.0, 0.0, 0.0, 0.0);
  }
}
