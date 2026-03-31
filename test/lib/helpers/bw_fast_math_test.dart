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

import 'package:anthem/helpers/bw_fast_math.dart';
import 'package:flutter_test/flutter_test.dart';

const _ln2 = math.ln2;
const _ln10 = math.ln10;
const _log2E = math.log2e;
const _log10E = math.log10e;
const _twoPi = math.pi * 2.0;

double _wrap(double value, double period) => value.remainder(period);

bool _isNegativeZero(double value) => value == 0.0 && value.isNegative;

void _expectExactDouble(double actual, double expected) {
  if (expected.isNaN) {
    expect(actual.isNaN, isTrue);
    return;
  }

  expect(actual, expected);
  if (expected == 0.0) {
    expect(actual.isNegative, expected.isNegative);
  }
}

void _expectAbsOrRel(
  double actual,
  double expected, {
  required double absTolerance,
  required double relTolerance,
}) {
  if (expected.isNaN) {
    expect(actual.isNaN, isTrue);
    return;
  }

  if (expected.isInfinite) {
    expect(actual, expected);
    return;
  }

  final absError = (actual - expected).abs();
  final relError = expected == 0.0
      ? double.infinity
      : absError / expected.abs();

  expect(
    absError <= absTolerance || relError <= relTolerance,
    isTrue,
    reason:
        'actual=$actual expected=$expected absError=$absError relError=$relError',
  );
}

double _refCopySign(double x, double y) {
  final magnitude = x.abs();
  return y.isNegative ? -magnitude : magnitude;
}

double _refMin0(double x) => x.isNegative ? x : 0.0;

double _refMax0(double x) => x > 0.0 ? x : 0.0;

double _refMin(double a, double b) => a < b ? a : b;

double _refMax(double a, double b) => a > b ? a : b;

double _refClip(double x, double min, double max) =>
    _refMin(_refMax(x, min), max);

double _refSin2Pi(double x) => math.sin(_twoPi * _wrap(x, 1.0));

double _refCos2Pi(double x) => math.cos(_twoPi * _wrap(x, 1.0));

double _refTan2Pi(double x) => math.tan(_twoPi * _wrap(x, 0.5));

double _refSin(double x) => math.sin(_wrap(x, _twoPi));

double _refCos(double x) => math.cos(_wrap(x, _twoPi));

double _refTan(double x) => math.tan(_wrap(x, math.pi));

double _refLog2(double x) => math.log(x) * _log2E;

double _refLog10(double x) => math.log(x) * _log10E;

double _refPow2(double x) => math.exp(x * _ln2);

double _refPow10(double x) => math.exp(x * _ln10);

double _refLog2OnePlusPow2(double x) {
  if (x <= 0.0) {
    return _refLog2(1.0 + _refPow2(x));
  }

  return x + _refLog2(1.0 + _refPow2(-x));
}

double _refLogOnePlusExp(double x) {
  if (x <= 0.0) {
    return math.log(1.0 + math.exp(x));
  }

  return x + math.log(1.0 + math.exp(-x));
}

double _refLog10OnePlusPow10(double x) {
  if (x <= 0.0) {
    return _refLog10(1.0 + _refPow10(x));
  }

  return x + _refLog10(1.0 + _refPow10(-x));
}

double _refSinh(double x) {
  if (x == 0.0) {
    return x;
  }

  final magnitude = x.abs();
  if (magnitude >= 20.0) {
    return _refCopySign(0.5 * math.exp(magnitude), x);
  }

  return 0.5 * (math.exp(x) - math.exp(-x));
}

double _refCosh(double x) {
  final magnitude = x.abs();
  if (magnitude >= 20.0) {
    return 0.5 * math.exp(magnitude);
  }

  return 0.5 * (math.exp(magnitude) + math.exp(-magnitude));
}

double _refTanh(double x) {
  if (x == 0.0) {
    return x;
  }

  final magnitude = x.abs();
  if (magnitude >= 20.0) {
    return _refCopySign(1.0, x);
  }

  final exp2x = math.exp(2.0 * magnitude);
  return _refCopySign((exp2x - 1.0) / (exp2x + 1.0), x);
}

double _refSech(double x) {
  final expNegAbs = math.exp(-x.abs());
  return (2.0 * expNegAbs) / (1.0 + expNegAbs * expNegAbs);
}

double _refAsinh(double x) {
  if (x == 0.0 || x.isInfinite) {
    return x;
  }

  final magnitude = x.abs();
  final result = magnitude > 1e154
      ? math.log(magnitude) + _ln2
      : math.log(magnitude + math.sqrt(magnitude * magnitude + 1.0));
  return _refCopySign(result, x);
}

double _refAcosh(double x) {
  if (x < 1.0) {
    return double.nan;
  }

  if (x == 1.0) {
    return 0.0;
  }

  if (x.isInfinite) {
    return double.infinity;
  }

  if (x > 1e154) {
    return math.log(x) + _ln2;
  }

  return math.log(x + math.sqrt(x - 1.0) * math.sqrt(x + 1.0));
}

void main() {
  group('integer helpers', () {
    test('sign fill matches 64-bit signed semantics', () {
      expect(bwSignFill(-0x8000000000000000), -1);
      expect(bwSignFill(-1), -1);
      expect(bwSignFill(0), 0);
      expect(bwSignFill(1), 0);
      expect(bwSignFill(0x7fffffffffffffff), 0);
    });

    test('signed min/max/clip match slow reference logic', () {
      const samples = <int>[
        -0x8000000000000000,
        -100,
        -1,
        0,
        1,
        100,
        0x7fffffffffffffff,
      ];

      for (final a in samples) {
        for (final b in samples) {
          expect(bwMinInt(a, b), a < b ? a : b);
          expect(bwMaxInt(a, b), a > b ? a : b);
        }
      }

      const ranges = <(int, int)>[(-10, 10), (-1, 1), (0, 0), (10, 20)];
      for (final (min, max) in ranges) {
        for (final sample in samples) {
          final expected = sample < min ? min : (sample > max ? max : sample);
          expect(bwClipInt(sample, min, max), expected);
        }
      }
    });
  });

  group('exact floating-point helpers', () {
    const signedSamples = <double>[
      double.infinity,
      1000.0,
      1.0,
      1e-3,
      0.0,
      -0.0,
      -1e-3,
      -1.0,
      -1000.0,
      double.negativeInfinity,
    ];

    test('copy sign preserves sign bits, including signed zero', () {
      for (final x in signedSamples) {
        for (final y in signedSamples) {
          _expectExactDouble(bwCopySign(x, y), _refCopySign(x, y));
        }
      }
    });

    test('sign behaves like Brickworks for signed zero', () {
      for (final value in signedSamples) {
        final expected = value > 0.0 ? 1.0 : (value < 0.0 ? -1.0 : 0.0);
        _expectExactDouble(bwSign(value), expected);
      }
    });

    test('abs/min/max/clip preserve expected zero-sign behavior', () {
      for (final value in signedSamples) {
        _expectExactDouble(bwAbs(value), value.abs());
        _expectExactDouble(bwMin0(value), _refMin0(value));
        _expectExactDouble(bwMax0(value), _refMax0(value));
      }

      for (final a in signedSamples) {
        for (final b in signedSamples) {
          _expectExactDouble(bwMin(a, b), _refMin(a, b));
          _expectExactDouble(bwMax(a, b), _refMax(a, b));
        }
      }

      const bounds = <(double, double)>[
        (double.negativeInfinity, double.infinity),
        (-1.0, 1.0),
        (-1e-3, 1e-3),
        (0.0, 0.0),
      ];
      for (final (min, max) in bounds) {
        for (final value in signedSamples) {
          _expectExactDouble(
            bwClip(value, min, max),
            _refClip(value, min, max),
          );
        }
      }
    });

    test('rounding helpers match Dart reference operations', () {
      const samples = <double>[
        1.234e38,
        1001.0,
        1000.9,
        1000.5,
        1000.1,
        1.5,
        1.0,
        0.9,
        0.5,
        0.1,
        0.0,
        -0.0,
        -0.1,
        -0.5,
        -0.9,
        -1.0,
        -1.5,
        -1000.1,
        -1000.5,
        -1000.9,
        -1.234e38,
        double.infinity,
        double.negativeInfinity,
      ];

      for (final sample in samples) {
        _expectExactDouble(bwTrunc(sample), sample.truncateToDouble());
        _expectExactDouble(bwRound(sample), sample.roundToDouble());
        _expectExactDouble(bwFloor(sample), sample.floorToDouble());
        _expectExactDouble(bwCeil(sample), sample.ceilToDouble());
      }

      expect(_isNegativeZero(bwRound(-0.1)), isTrue);
      expect(_isNegativeZero(bwTrunc(-0.1)), isTrue);
      expect(_isNegativeZero(bwFloor(-0.0)), isTrue);
      expect(_isNegativeZero(bwCeil(-0.0)), isTrue);
    });

    test('intFrac matches floor plus remainder decomposition', () {
      const samples = <double>[
        -1000.9,
        -1000.5,
        -1.5,
        -0.1,
        -0.0,
        0.0,
        0.1,
        1.5,
        999.25,
        1000.9,
      ];

      for (final sample in samples) {
        final result = bwIntFrac(sample);
        final expectedInteger = sample.floorToDouble();
        final expectedFraction = sample - expectedInteger;
        _expectExactDouble(result.integerPart, expectedInteger);
        _expectExactDouble(result.fractionalPart, expectedFraction);
      }
    });
  });

  group('transcendental helpers', () {
    test('reciprocal matches direct division', () {
      const samples = <double>[
        -1e12,
        -10.0,
        -1.0,
        -1e-6,
        1e-6,
        1.0,
        10.0,
        1e12,
      ];

      for (final sample in samples) {
        _expectAbsOrRel(
          bwReciprocal(sample),
          1.0 / sample,
          absTolerance: 0.0,
          relTolerance: 1.3e-5,
        );
      }
    });

    test('trigonometric helpers stay within Brickworks error bounds', () {
      const samples2Pi = <double>[
        -1000.25,
        -10.125,
        -1.5,
        -0.125,
        -0.01,
        -0.0,
        0.0,
        0.01,
        0.125,
        1.5,
        10.125,
        1000.25,
      ];
      for (final sample in samples2Pi) {
        _expectAbsOrRel(
          bwSin2Pi(sample),
          _refSin2Pi(sample),
          absTolerance: 0.011,
          relTolerance: 0.017,
        );
        _expectAbsOrRel(
          bwCos2Pi(sample),
          _refCos2Pi(sample),
          absTolerance: 0.011,
          relTolerance: 0.017,
        );
      }

      const tan2PiSamples = <double>[
        -10.24,
        -1.24,
        -0.24,
        -0.1,
        0.0,
        0.1,
        0.24,
        1.24,
        10.24,
      ];
      for (final sample in tan2PiSamples) {
        _expectAbsOrRel(
          bwTan2Pi(sample),
          _refTan2Pi(sample),
          absTolerance: 0.06,
          relTolerance: 0.008,
        );
      }

      const samples = <double>[
        -1000.0,
        -100.0,
        -10.0,
        -1.0,
        -0.5,
        -0.1,
        -0.0,
        0.0,
        0.1,
        0.5,
        1.0,
        10.0,
        100.0,
        1000.0,
      ];
      for (final sample in samples) {
        _expectAbsOrRel(
          bwSin(sample),
          _refSin(sample),
          absTolerance: 0.011,
          relTolerance: 0.017,
        );
        _expectAbsOrRel(
          bwCos(sample),
          _refCos(sample),
          absTolerance: 0.011,
          relTolerance: 0.017,
        );
      }

      const tanSamples = <double>[
        -10.0,
        -3.0,
        -1.0,
        -0.5,
        -0.1,
        0.0,
        0.1,
        0.5,
        1.0,
        3.0,
        10.0,
      ];
      for (final sample in tanSamples) {
        _expectAbsOrRel(
          bwTan(sample),
          _refTan(sample),
          absTolerance: 0.06,
          relTolerance: 0.008,
        );
      }
    });

    test('log and power helpers stay within Brickworks error bounds', () {
      const positiveSamples = <double>[
        1e-300,
        1e-12,
        1e-6,
        0.1,
        1.0,
        2.0,
        10.0,
        1e6,
        1e300,
      ];
      for (final sample in positiveSamples) {
        _expectAbsOrRel(
          bwLog2(sample),
          _refLog2(sample),
          absTolerance: 0.0055,
          relTolerance: 0.012,
        );
        _expectAbsOrRel(
          bwLog(sample),
          math.log(sample),
          absTolerance: 0.0038,
          relTolerance: 0.012,
        );
        _expectAbsOrRel(
          bwLog10(sample),
          _refLog10(sample),
          absTolerance: 0.0017,
          relTolerance: 0.012,
        );
        _expectAbsOrRel(
          bwSqrt(sample),
          math.sqrt(sample),
          absTolerance: 1.09e-19,
          relTolerance: 7e-6,
        );
        _expectAbsOrRel(
          bwLinearToDb(sample),
          20.0 * _refLog10(sample),
          absTolerance: 0.032,
          relTolerance: 0.012,
        );
      }

      const exponentSamples = <double>[
        -1000.0,
        -100.0,
        -10.0,
        -1.0,
        -1e-6,
        0.0,
        1e-6,
        1.0,
        10.0,
        100.0,
        300.0,
      ];
      for (final sample in exponentSamples) {
        _expectAbsOrRel(
          bwPow2(sample),
          _refPow2(sample),
          absTolerance: 0.0,
          relTolerance: 6.2e-4,
        );
        _expectAbsOrRel(
          bwExp(sample),
          math.exp(sample),
          absTolerance: 0.0,
          relTolerance: 6.2e-4,
        );
      }

      const decimalExponentSamples = <double>[
        -300.0,
        -100.0,
        -10.0,
        -1.0,
        -1e-6,
        0.0,
        1e-6,
        1.0,
        10.0,
        100.0,
        300.0,
      ];
      for (final sample in decimalExponentSamples) {
        _expectAbsOrRel(
          bwPow10(sample),
          _refPow10(sample),
          absTolerance: 0.0,
          relTolerance: 6.2e-4,
        );
        _expectAbsOrRel(
          bwDbToLinear(sample),
          _refPow10(sample / 20.0),
          absTolerance: 0.0,
          relTolerance: 6.2e-4,
        );
      }
    });

    test('softplus-style helpers stay within Brickworks error bounds', () {
      const samples = <double>[
        -1000.0,
        -100.0,
        -10.0,
        -1.0,
        -1e-6,
        -0.0,
        0.0,
        1e-6,
        1.0,
        10.0,
        100.0,
        1000.0,
      ];

      for (final sample in samples) {
        _expectAbsOrRel(
          bwLog2OnePlusPow2(sample),
          _refLog2OnePlusPow2(sample),
          absTolerance: 0.006,
          relTolerance: double.infinity,
        );
        _expectAbsOrRel(
          bwLogOnePlusExp(sample),
          _refLogOnePlusExp(sample),
          absTolerance: 0.004,
          relTolerance: double.infinity,
        );
        _expectAbsOrRel(
          bwLog10OnePlusPow10(sample),
          _refLog10OnePlusPow10(sample),
          absTolerance: 0.002,
          relTolerance: double.infinity,
        );
      }
    });

    test('hyperbolic helpers stay within Brickworks error bounds', () {
      const samples = <double>[
        -700.0,
        -100.0,
        -10.0,
        -1.0,
        -1e-6,
        -0.0,
        0.0,
        1e-6,
        1.0,
        10.0,
        100.0,
        700.0,
      ];

      for (final sample in samples) {
        _expectAbsOrRel(
          bwSinh(sample),
          _refSinh(sample),
          absTolerance: 1e-7,
          relTolerance: 7e-4,
        );
        _expectAbsOrRel(
          bwCosh(sample),
          _refCosh(sample),
          absTolerance: 0.0,
          relTolerance: 7e-4,
        );
        _expectAbsOrRel(
          bwTanh(sample),
          _refTanh(sample),
          absTolerance: 0.035,
          relTolerance: 0.065,
        );
        _expectAbsOrRel(
          bwSech(sample),
          _refSech(sample),
          absTolerance: 1e-9,
          relTolerance: 7e-4,
        );
      }
    });

    test('inverse hyperbolic helpers stay within Brickworks error bounds', () {
      const asinhSamples = <double>[
        -1e300,
        -1e100,
        -100.0,
        -10.0,
        -1.0,
        -1e-6,
        -0.0,
        0.0,
        1e-6,
        1.0,
        10.0,
        100.0,
        1e100,
        1e300,
      ];
      for (final sample in asinhSamples) {
        _expectAbsOrRel(
          bwAsinh(sample),
          _refAsinh(sample),
          absTolerance: 0.004,
          relTolerance: 0.012,
        );
      }

      const acoshSamples = <double>[
        1.0,
        1.000001,
        2.0,
        10.0,
        100.0,
        1e6,
        1e100,
        1e300,
      ];
      for (final sample in acoshSamples) {
        _expectAbsOrRel(
          bwAcosh(sample),
          _refAcosh(sample),
          absTolerance: 0.004,
          relTolerance: 0.008,
        );
      }

      expect(bwAcosh(0.5).isNaN, isTrue);
    });
  });
}
