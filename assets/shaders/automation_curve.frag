/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

// This shader draws the curve beteween two automation points.
//
// This shader is passable, but still has a couple issues:
// - Adjacent curves do not always appear to connect with each other
// - The curve sometimes draws incorrectly near the edges, due to how it
//   prevents math from blowing up

#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 resolution;
uniform float devicePixelRatio;

// FlutterFragCoord() is relative to the top-left of the canvas. This shader
// pass represents a single curve, and will likely have an offset from the
// top-left of the canvas. The uniform below uniform encodes this offset.
uniform vec2 offset;

uniform float lastPointY;
uniform float thisPointY;
uniform float tension;

// The number of pixels between the left side of the shader draw area and the
// start of the curve
uniform float startOffset;
// The number of pixels between the right side of the shader draw area and the
// end of the curve
uniform float endOffset;

// Stroke width in display-independent pixels (multiply by devicePixelRatio to get actual pixels)
uniform float unAdjustedStrokeWidth;

uniform vec4 color;
uniform float gradientOpacityTop;
uniform float gradientOpacityBottom;

out vec4 fragColor;

const float linearCenterTransitionRate = 0.27;
const float linearCenterWidth = 1.6;
const float pi = 3.1415926538;

// Curve functions

float g(float x) {
  return atan(x * linearCenterTransitionRate * pi) / pi + 0.5;
}

float getLinearCenterInterpolation(float tension) {
  return 1.0 -
      (g(tension + linearCenterWidth) +
          (1.0 - g(tension - linearCenterWidth)) -
          1.0);
}

// Gets the raw tension value for the smooth curve type. The tension value
// provided to this shader must be run through this function before being used
// in the smoothCurve function.
//
// The purpose of this function is to make the tension value feel more natural.
// Without it, the tension value moves too slowly near the edge and too quickly
// near the center.
float getRawTensionForSmooth(float tension) {
  float scaledTension = tension * 15.0;
  float linearCenterInterpolation = getLinearCenterInterpolation(scaledTension);

  // This is also why we're having issues in the Dart version of this function
  float powVal = 1.0;
  if (tension > 0.0) {
    powVal = pow(scaledTension / 2.0, 2.2);
  } else if (tension < 1.0) {
    powVal = -pow(-scaledTension / 2.0, 2.2);
  }

  return powVal * linearCenterInterpolation +
      0.7 * scaledTension * (1.0 - linearCenterInterpolation);
}

float smoothCurve(float normalizedX, float rawTension) {
  if (rawTension >= 0.0) {
    return pow(normalizedX, rawTension + 1.0);
  } else {
    return 1.0 - pow(1.0 - normalizedX, -rawTension + 1.0);
  }
}

vec2 projectPointOntoLine(vec2 A, vec2 B, vec2 point) {
  // Compute vectors relative to A
  vec2 AP = point - A;
  vec2 AB = B - A;
  
  // Compute the projection of point onto the line AB
  vec2 projection = A + (dot(AP, AB) / dot(AB, AB)) * AB;
  
  return projection;
}

vec2 projectPointOntoLineSegment(vec2 point, vec2 a, vec2 b) {
  vec2 ab = b - a;
  vec2 ap = point - a;

  float abLength = length(ab);
  vec2 abNormalized = ab / abLength;

  float apDotAb = dot(ap, abNormalized);

  // Clamp the dot product to the length of the line segment
  apDotAb = max(0, min(abLength, apDotAb));

  vec2 apProjected = abNormalized * apDotAb + a;

  return apProjected;
}

float getY(float x, float startY, float endY, float tension) {
  return smoothCurve(x, tension) * (endY - startY) + startY;
}

// Approximates the closest point on the curve to the given point.
//
// This is done by getting two line segments along the curve, and projecting the
// point onto each of them. The closest projected point is then returned.
//
// We could use more lines to get a more accurate result, but two seems to be
// working for now. More lines may produce better antialiasing with more extreme
// slope changes.
vec2 getClosestCurvePoint(vec2 pointUv, float tension) {
  float strokeWidth = unAdjustedStrokeWidth * devicePixelRatio;

  // Get the size of a pixel in uv coordinates, as a Vec2
  vec2 uvPixelSize = 1.0 / resolution.xy;

  // Get three points to use for tangent lines
  float moveDist = (strokeWidth * uvPixelSize.x) * 2;

  vec2 point1 = vec2(
    (pointUv.x - moveDist),
    getY(pointUv.x - moveDist, lastPointY, thisPointY, tension)
  );
  vec2 point2 = vec2(pointUv.x, getY(pointUv.x, lastPointY, thisPointY, tension));
  vec2 point3 = vec2(
    pointUv.x + moveDist,
    getY(pointUv.x + moveDist, lastPointY, thisPointY, tension)
  );

  vec2 originalPoint = pointUv * resolution.xy;

  // Project the point onto each tangent line
  vec2 projectedPoint1 = projectPointOntoLineSegment(originalPoint, point1 * resolution.xy, point2 * resolution.xy);
  vec2 projectedPoint2 = projectPointOntoLineSegment(originalPoint, point2 * resolution.xy, point3 * resolution.xy);

  // Get the square distance to each projected point
  float distance1 = distance(originalPoint, projectedPoint1);
  float distance2 = distance(originalPoint, projectedPoint2);

  // The first two branches here prevent the math from blowing up, but cause the
  // line to draw incorrectly in some cases. This should be refined, but I've
  // already spent far too long on this so I'm leaving it as-is for now.
  if (tension <= 0 && pointUv.x + moveDist >= 1.0) {
    return projectedPoint1;
  } else if (tension > 0 && pointUv.x - moveDist < 0) {
    return projectedPoint2;
  } else if ((distance1 < distance2)) {
    return projectedPoint1;
  } else {
    return projectedPoint2;
  }
}

// From https://stackoverflow.com/a/28095165/8166701
// Gold Noise ©2015 dcerisano@standard3d.com
// - based on the Golden Ratio
// - uniform normalized distribution
// - fastest static noise generator function (also runs at low precision)
// - use with indicated fractional seeding method. 

float PHI = 1.61803398874989484820459;  // Φ = Golden Ratio   

float goldNoise(in vec2 xy, in float seed) {
  return fract(tan(distance(xy * PHI, xy) * seed) * xy.x);
}

void main() {
  vec2 uv = vec2(FlutterFragCoord().x - offset.x - startOffset, FlutterFragCoord().y - offset.y) / resolution.xy;
  uv = vec2(uv.x, 1 - uv.y);

  float startY = lastPointY;
  float endY = thisPointY;
  float strokeWidth = unAdjustedStrokeWidth * devicePixelRatio;

  float rawTension = getRawTensionForSmooth(tension);
  float y = getY(uv.x, startY, endY, rawTension);

  vec2 closestCurvePoint = getClosestCurvePoint(uv, rawTension);
  
  float dist = distance(uv * resolution, closestCurvePoint);

  vec4 backgroundColor = vec4(0.0, 0.0, 0.0, 0.0);
  if (uv.y < y && uv.x >= 0 && uv.x < 1) {
    float rand = goldNoise(uv * resolution, 0.25) * 0.1 + 0.9;
    float opacity = (uv.y * (gradientOpacityTop - gradientOpacityBottom) + gradientOpacityBottom) * rand;
    // Flutter requires us to supply colors with premultiplied alpha, which is
    // why we multiply the color component with shadedOpacity.
    backgroundColor = vec4(color.xyz * opacity, opacity);
  }

  float lineStrength = ((strokeWidth + devicePixelRatio * 2) * 0.5) - dist * devicePixelRatio;

  // Prevent line from painting above the top point or below the bottom.
  //
  // The best thing would be something like finding a tangent line and the
  // associated vector, and using that to create a round line cap. We have to
  // basically draw a half-circle in that case, but the half-circle must be
  // aligned with the tangent line and facing the correct direction. There are
  // more pressing issues to deal with in the shader right now, so I'm leaving
  // this as-is for the moment.
  //
  // As-is, the code is pretty simplistic. It fades out the line over the course
  // of one pixel, starting at 0.5 * stroke width above the top of the curve and
  // below the bottom.
  float top = max(startY, endY);
  float bottom = min(startY, endY);
  if (uv.y > top) {
    //                                                         \/ I have no idea why + 2 here is necessary
    lineStrength = lineStrength * min(1, max(0, (strokeWidth + 2) * 0.5 - (uv.y - top) * resolution.y));
  } else if (uv.y < bottom) {
    lineStrength = lineStrength * min(1, max(0, (strokeWidth + 2) * 0.5 - (bottom - uv.y) * resolution.y));
  }

  // Mix with line
  fragColor = mix(backgroundColor, color, min(1, max(0, lineStrength)));
}
