/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:math' as math;
import 'dart:typed_data';

typedef BwIntFrac = ({double integerPart, double fractionalPart});

const int _bwInt64Min = -(1 << 63);
const int _bwInt64Max = (1 << 63) - 1;

const int _bwDoubleExponentBias = 1023;
const int _bwDoubleMantissaBits = 52;
const int _bwDoubleMantissaMask = 0x000fffffffffffff;
const int _bwDoubleOneBits = 0x3ff0000000000000;

const double _bwDoubleMinNormal = 2.2250738585072014e-308;
const double _bwInvTwoPi = 0.15915494309189535;
const double _bwLn2 = 0.6931471805599453;
const double _bwLog10Of2 = 0.3010299956639812;

// dart2js cannot safely support the 64-bit typed-data accessors used by the
// bit-level fast path below, so JS web builds use exact math fallbacks.
const bool _bwUseJsFallback = bool.fromEnvironment('dart.tool.dart2js');

bool _isSigned64(int value) => value >= _bwInt64Min && value <= _bwInt64Max;

int _doubleToBits(double value) {
  final data = ByteData(8)..setFloat64(0, value, Endian.host);
  return data.getUint64(0, Endian.host);
}

double _bitsToDouble(int bits) {
  final data = ByteData(8)..setUint64(0, bits, Endian.host);
  return data.getFloat64(0, Endian.host);
}

/// Returns `-1` if [x] is negative, `0` otherwise.
int bwSignFill(int x) {
  assert(_isSigned64(x));
  return x < 0 ? -1 : 0;
}

/// Returns the minimum of [a] and [b].
int bwMinInt(int a, int b) {
  assert(_isSigned64(a));
  assert(_isSigned64(b));
  return a < b ? a : b;
}

/// Returns the maximum of [a] and [b].
int bwMaxInt(int a, int b) {
  assert(_isSigned64(a));
  assert(_isSigned64(b));
  return a > b ? a : b;
}

/// Clamps [x] to the inclusive range `[min, max]`.
int bwClipInt(int x, int min, int max) {
  assert(_isSigned64(x));
  assert(_isSigned64(min));
  assert(_isSigned64(max));
  assert(max >= min);
  return x < min ? min : (x > max ? max : x);
}

/// Returns a value with the magnitude of [x] and the sign of [y].
double bwCopySign(double x, double y) {
  final magnitude = x.abs();
  return y.isNegative ? -magnitude : magnitude;
}

/// Returns `1.0` for positive values, `-1.0` for negative values, and `0.0` for zero.
double bwSign(double x) {
  if (x.isNaN) {
    return x;
  }

  if (x > 0.0) {
    return 1.0;
  }

  if (x < 0.0) {
    return -1.0;
  }

  return 0.0;
}

/// Returns the absolute value of [x].
double bwAbs(double x) => x.abs();

/// Returns the minimum of `0.0` and [x].
double bwMin0(double x) {
  if (x.isNaN) {
    return x;
  }

  return x.isNegative ? x : 0.0;
}

/// Returns the maximum of `0.0` and [x].
double bwMax0(double x) {
  if (x.isNaN) {
    return x;
  }

  return x > 0.0 ? x : 0.0;
}

/// Returns the minimum of [a] and [b].
double bwMin(double a, double b) {
  if (a.isNaN) {
    return a;
  }

  if (b.isNaN) {
    return b;
  }

  return a < b ? a : b;
}

/// Returns the maximum of [a] and [b].
double bwMax(double a, double b) {
  if (a.isNaN) {
    return a;
  }

  if (b.isNaN) {
    return b;
  }

  return a > b ? a : b;
}

/// Clamps [x] to the inclusive range `[min, max]`.
double bwClip(double x, double min, double max) {
  assert(max >= min);
  return bwMin(bwMax(x, min), max);
}

/// Returns [x] rounded toward zero.
double bwTrunc(double x) => x.truncateToDouble();

/// Returns [x] rounded to the nearest integer, with halfway cases away from zero.
double bwRound(double x) => x.roundToDouble();

/// Returns [x] rounded down.
double bwFloor(double x) => x.floorToDouble();

/// Returns [x] rounded up.
double bwCeil(double x) => x.ceilToDouble();

/// Splits [x] into its floor-based integer part and fractional remainder.
BwIntFrac bwIntFrac(double x) {
  final integerPart = bwFloor(x);
  return (integerPart: integerPart, fractionalPart: x - integerPart);
}

/// Returns an approximation of the base-2 logarithm of [x].
double bwLog2(double x) {
  assert(x.isFinite);
  assert(x >= _bwDoubleMinNormal);

  if (_bwUseJsFallback) {
    return math.log(x) * math.log2e;
  }

  final bits = _doubleToBits(x);
  final exponent = (bits >> _bwDoubleMantissaBits) & 0x7ff;
  final normalized = _bitsToDouble(
    (bits & _bwDoubleMantissaMask) | _bwDoubleOneBits,
  );

  return exponent.toDouble() -
      1025.2134752044448 +
      normalized *
          (3.148297929334117 +
              normalized *
                  (-1.098865286222744 + normalized * 0.1640425613334452));
}

/// Returns an approximation of the natural logarithm of [x].
double bwLog(double x) => _bwLn2 * bwLog2(x);

/// Returns an approximation of the base-10 logarithm of [x].
double bwLog10(double x) => _bwLog10Of2 * bwLog2(x);

/// Returns an approximation of `2^x`.
double bwPow2(double x) {
  assert(!x.isNaN);
  assert(x <= 1023.9999999999999);

  if (_bwUseJsFallback) {
    return math.exp(x * math.ln2);
  }

  if (x < -1022.0) {
    return 0.0;
  }

  final lower = x.floor();
  final fraction = x - lower;
  final scale = _bitsToDouble(
    (lower + _bwDoubleExponentBias) << _bwDoubleMantissaBits,
  );

  return scale +
      scale *
          fraction *
          (_bwLn2 +
              fraction * (0.2274112777602189 + fraction * 0.07944154167983575));
}

/// Returns an approximation of `e^x`.
double bwExp(double x) => bwPow2(1.4426950408889634 * x);

/// Returns an approximation of `10^x`.
double bwPow10(double x) => bwPow2(3.321928094887362 * x);

/// Returns an approximation of `1.0 / x`.
double bwReciprocal(double x) {
  assert(x.isFinite);
  assert(x.abs() >= _bwDoubleMinNormal);

  final magnitude = bwAbs(x);
  var y = bwPow2(-bwLog2(magnitude));
  y = y + y - magnitude * y * y;
  y = y + y - magnitude * y * y;
  return bwCopySign(y, x);
}

/// Returns an approximation of `sin(2 * pi * x)`.
double bwSin2Pi(double x) {
  x = x - bwFloor(x);
  final xp1 = x + x - 1.0;
  final xp2 = bwAbs(xp1);
  final xp = 1.570796326794897 - 1.570796326794897 * bwAbs(xp2 + xp2 - 1.0);

  return -bwCopySign(1.0, xp1) *
      (xp + xp * xp * (-0.05738534102710938 - 0.1107398163618408 * xp));
}

/// Returns an approximation of `sin(x)`.
double bwSin(double x) => bwSin2Pi(_bwInvTwoPi * x);

/// Returns an approximation of `cos(2 * pi * x)`.
double bwCos2Pi(double x) => bwSin2Pi(x + 0.25);

/// Returns an approximation of `cos(x)`.
double bwCos(double x) => bwCos2Pi(_bwInvTwoPi * x);

/// Returns an approximation of `tan(2 * pi * x)`.
double bwTan2Pi(double x) => bwSin2Pi(x) * bwReciprocal(bwCos2Pi(x));

/// Returns an approximation of `tan(x)`.
double bwTan(double x) {
  final scaled = _bwInvTwoPi * x;
  return bwSin2Pi(scaled) * bwReciprocal(bwCos2Pi(scaled));
}

/// Returns an approximation of `log2(1 + 2^x)`.
double bwLog2OnePlusPow2(double x) => x >= 32.0 ? x : bwLog2(1.0 + bwPow2(x));

/// Returns an approximation of `log(1 + exp(x))`.
double bwLogOnePlusExp(double x) => x >= 22.18070977791827
    ? x
    : _bwLn2 * bwLog2(1.0 + bwPow2(1.4426950408889634 * x));

/// Returns an approximation of `log10(1 + 10^x)`.
double bwLog10OnePlusPow10(double x) => x >= 9.632959861247409
    ? x
    : _bwLog10Of2 * bwLog2(1.0 + bwPow2(3.321928094887362 * x));

/// Converts decibels to a linear gain ratio using the fast approximation path.
double bwDbToLinear(double x) => bwPow2(0.16609640474436812 * x);

/// Converts a linear gain ratio to decibels using the fast approximation path.
double bwLinearToDb(double x) => 20.0 * bwLog10(x);

/// Returns an approximation of `sqrt(x)`.
double bwSqrt(double x) {
  assert(x.isFinite);
  assert(x >= 0.0);

  if (x < _bwDoubleMinNormal) {
    return 0.0;
  }

  var y = bwPow2(0.5 * bwLog2(x));
  y = 0.5 * (y + x * bwReciprocal(y));
  y = 0.5 * (y + x * bwReciprocal(y));
  return y;
}

/// Returns an approximation of the hyperbolic tangent of [x].
double bwTanh(double x) {
  final xm = bwClip(x, -2.115287308554551, 2.115287308554551);
  final axm = bwAbs(xm);
  return xm * axm * (0.01218073260037716 * axm - 0.2750231331124371) + xm;
}

/// Returns an approximation of the hyperbolic sine of [x].
double bwSinh(double x) => 0.5 * (bwExp(x) - bwExp(-x));

/// Returns an approximation of the hyperbolic cosine of [x].
double bwCosh(double x) => 0.5 * (bwExp(x) + bwExp(-x));

/// Returns an approximation of the hyperbolic secant of [x].
double bwSech(double x) {
  if (x * x >= 22.0 * 22.0) {
    return 0.0;
  }

  var y = bwReciprocal(bwExp(x) + bwExp(-x));
  y = y + y;
  return y;
}

/// Returns an approximation of the hyperbolic arcsine of [x].
double bwAsinh(double x) {
  final magnitude = bwAbs(x);
  final root = magnitude >= 4096.0
      ? magnitude
      : bwSqrt(magnitude * magnitude + 1.0);
  return bwCopySign(bwLog(root + magnitude), x);
}

/// Returns an approximation of the hyperbolic arccosine of [x].
double bwAcosh(double x) {
  if (x < 1.0) {
    return double.nan;
  }

  final root = x >= 8192.0 ? x : bwSqrt(x * x - 1.0);
  return bwLog(root + x);
}
