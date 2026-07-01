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

import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

const _checkboxSize = 16.0;
const _checkboxBorderRadius = 4.0;
const _checkboxLabelGap = 5.0;
const _checkboxLabelFontSize = 12.0;
const _checkboxHoverLightenAmount = 0.03;
const _checkboxPressLightenAmount = 0.06;

typedef _CheckboxColors = ({Color fill, Color border, Color checkmark});

class AnthemCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  const AnthemCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
  });

  @override
  State<AnthemCheckbox> createState() => _AnthemCheckboxState();
}

class _AnthemCheckboxState extends State<AnthemCheckbox> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onChanged != null;
    final colors = _resolveColors(
      hovered: interactive && hovered,
      pressed: interactive && pressed,
    );

    final checkbox = SizedBox.square(
      dimension: _checkboxSize,
      child: CustomPaint(
        painter: _CheckboxPainter(value: widget.value, colors: colors),
      ),
    );

    final content = widget.label == null
        ? checkbox
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              checkbox,
              const SizedBox(width: _checkboxLabelGap),
              Text(
                widget.label!,
                style: TextStyle(
                  color: AnthemTheme.text.main,
                  fontSize: _checkboxLabelFontSize,
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToLastDescent: false,
                ),
              ),
            ],
          );

    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return content;
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovered = false;
        });
      },
      child: Listener(
        onPointerDown: (_) {
          setState(() {
            pressed = true;
          });
        },
        onPointerUp: (_) {
          setState(() {
            pressed = false;
          });
        },
        onPointerCancel: (_) {
          setState(() {
            pressed = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!widget.value),
          child: content,
        ),
      ),
    );
  }
}

class _CheckboxPainter extends CustomPainter {
  final bool value;
  final _CheckboxColors colors;

  const _CheckboxPainter({required this.value, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = colors.fill
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = colors.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final outerRect = Offset.zero & size;
    final borderRect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        outerRect,
        const Radius.circular(_checkboxBorderRadius),
      ),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        borderRect,
        const Radius.circular(_checkboxBorderRadius - 0.5),
      ),
      borderPaint,
    );

    if (!value) {
      return;
    }

    final checkPaint = Paint()
      ..color = colors.checkmark
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(4, 8)
      ..lineTo(7, 11)
      ..lineTo(12, 5);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _CheckboxPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.colors != colors;
  }
}

_CheckboxColors _resolveColors({required bool hovered, required bool pressed}) {
  final idleColors = (
    fill: AnthemTheme.panel.backgroundDark,
    border: AnthemTheme.panel.border,
    checkmark: AnthemTheme.primary.main,
  );

  if (pressed) {
    return _lightenColors(idleColors, _checkboxPressLightenAmount);
  }

  if (hovered) {
    return _lightenColors(idleColors, _checkboxHoverLightenAmount);
  }

  return idleColors;
}

_CheckboxColors _lightenColors(_CheckboxColors colors, double amount) {
  return (
    fill: _lighten(colors.fill, amount),
    border: colors.border,
    checkmark: _lighten(colors.checkmark, amount),
  );
}

Color _lighten(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  final lightness = (hsl.lightness + amount).clamp(0.0, 1.0).toDouble();

  return hsl.withLightness(lightness).toColor();
}
