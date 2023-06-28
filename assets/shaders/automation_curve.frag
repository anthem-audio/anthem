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
uniform sampler2D uBackground;

out vec4 fragColor;

void main() {
  vec2 st = FlutterFragCoord().xy / resolution.xy;

  vec4 colorFromBackground = texture(uBackground, st);

  // Specify your target color. Here's an example of blue-green.
  vec4 targetColor = vec4(0.0, 0.5, 0.5, 1.0);

  // Use the x component of st as a mix factor to create a gradient along the x axis
  fragColor = mix(colorFromBackground, targetColor, st.x);
}
