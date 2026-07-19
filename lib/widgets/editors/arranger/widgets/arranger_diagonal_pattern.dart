/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

const _tileCellCount = 6;
const _backgroundColor = Color(0xFF2F2F2F);

/// Rounds to the nearest integer, with exact half values rounded down.
@visibleForTesting
int arrangerPatternPixelScaleForDevicePixelRatio(double devicePixelRatio) {
  assert(devicePixelRatio.isFinite && devicePixelRatio > 0);

  final lowerScale = devicePixelRatio.floor();
  final roundedScale = devicePixelRatio - lowerScale > 0.5
      ? lowerScale + 1
      : lowerScale;

  return max(1, roundedScale);
}

/// Efficiently paints a repeating diagonal pixel pattern behind [child].
///
/// The six-by-six source pattern is rasterized once for each integer pixel
/// scale and repeated by an image shader. Painting the widget is therefore a
/// single rectangle draw, regardless of its size.
class ArrangerDiagonalPattern extends StatefulWidget {
  final Widget? child;

  const ArrangerDiagonalPattern({super.key, this.child});

  @override
  State<ArrangerDiagonalPattern> createState() =>
      _ArrangerDiagonalPatternState();
}

class _ArrangerDiagonalPatternState extends State<ArrangerDiagonalPattern> {
  double? _devicePixelRatio;
  int? _pixelScale;
  ui.ImageShader? _shader;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final devicePixelRatio = View.of(context).devicePixelRatio;
    final pixelScale = arrangerPatternPixelScaleForDevicePixelRatio(
      devicePixelRatio,
    );
    final pixelScaleChanged = pixelScale != _pixelScale;

    if (devicePixelRatio == _devicePixelRatio && !pixelScaleChanged) {
      return;
    }

    _devicePixelRatio = devicePixelRatio;
    _pixelScale = pixelScale;
    _replaceShader(
      image: _ArrangerPatternTileCache.imageFor(pixelScale),
      devicePixelRatio: devicePixelRatio,
    );
  }

  void _replaceShader({
    required ui.Image image,
    required double devicePixelRatio,
  }) {
    _shader?.dispose();

    final imagePixelToLogicalPixel = 1 / devicePixelRatio;
    final transform = Matrix4.diagonal3Values(
      imagePixelToLogicalPixel,
      imagePixelToLogicalPixel,
      1,
    );
    _shader = ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      transform.storage,
      filterQuality: FilterQuality.none,
    );
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArrangerDiagonalPatternPainter(shader: _shader),
      child: widget.child,
    );
  }
}

class _ArrangerDiagonalPatternPainter extends CustomPainter {
  final ui.Shader? shader;
  late final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..color = shader == null ? _backgroundColor : const Color(0xFFFFFFFF)
    ..shader = shader;

  _ArrangerDiagonalPatternPainter({required this.shader});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(covariant _ArrangerDiagonalPatternPainter oldDelegate) {
    return shader != oldDelegate.shader;
  }
}

class _ArrangerPatternTileCache {
  // These images are tiny and shared by every pattern widget. Keeping them for
  // the process lifetime avoids repeated rasterization and texture uploads.
  static final _imagesByPixelScale = <int, ui.Image>{};

  static ui.Image imageFor(int pixelScale) {
    return _imagesByPixelScale.putIfAbsent(
      pixelScale,
      () => _createImage(pixelScale),
    );
  }

  static ui.Image _createImage(int pixelScale) {
    final tileSize = _tileCellCount * pixelScale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(_backgroundColor, BlendMode.src);
    final stripePaint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFF4E4E4E);

    for (var cellY = 0; cellY < _tileCellCount; cellY++) {
      for (final cellX in [cellY, (cellY + 1) % _tileCellCount]) {
        canvas.drawRect(
          Rect.fromLTWH(
            cellX * pixelScale.toDouble(),
            cellY * pixelScale.toDouble(),
            pixelScale.toDouble(),
            pixelScale.toDouble(),
          ),
          stripePaint,
        );
      }
    }

    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(tileSize, tileSize);
    } finally {
      picture.dispose();
    }
  }
}
