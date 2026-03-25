import 'dart:math';

const double _pi4Plus0273 = pi / 4.0 + 0.273;
const double _pi2 = pi / 2.0;

// Based on https://github.com/ducha-aiki/fast_atan2/blob/master/fast_atan.cpp
//
// This approximation is used in the downsampling hot loop where speed matters
// more than perfect precision.
double fastAtan2(double y, double x) {
  final double absY = y.abs();
  final double absX = x.abs();

  // In Dart, booleans can't be used as ints, so use ? 1 : 0.
  final int octant =
      ((x < 0 ? 1 : 0) << 2) +
      ((y < 0 ? 1 : 0) << 1) +
      ((absX <= absY) ? 1 : 0);

  switch (octant) {
    case 0:
      {
        if (x == 0 && y == 0) {
          return 0.0;
        }
        final double val = absY / absX;
        return (_pi4Plus0273 - 0.273 * val) * val; // 1st octant
      }
    case 1:
      {
        if (x == 0 && y == 0) {
          return 0.0;
        }
        final double val = absX / absY;
        return _pi2 - (_pi4Plus0273 - 0.273 * val) * val; // 2nd octant
      }
    case 2:
      {
        final double val = absY / absX;
        return -(_pi4Plus0273 - 0.273 * val) * val; // 8th octant
      }
    case 3:
      {
        final double val = absX / absY;
        return -_pi2 + (_pi4Plus0273 - 0.273 * val) * val; // 7th octant
      }
    case 4:
      {
        final double val = absY / absX;
        return pi - (_pi4Plus0273 - 0.273 * val) * val; // 4th octant
      }
    case 5:
      {
        final double val = absX / absY;
        return _pi2 + (_pi4Plus0273 - 0.273 * val) * val; // 3rd octant
      }
    case 6:
      {
        final double val = absY / absX;
        return -pi + (_pi4Plus0273 - 0.273 * val) * val; // 5th octant
      }
    case 7:
      {
        final double val = absX / absY;
        return -_pi2 - (_pi4Plus0273 - 0.273 * val) * val; // 6th octant
      }
    default:
      return 0.0;
  }
}
