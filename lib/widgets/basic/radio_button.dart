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

const _radioButtonSize = 16.0;
const _radioButtonLabelGap = 5.0;
const _radioButtonLabelFontSize = 12.0;
const _radioButtonHoverLightenAmount = 0.03;
const _radioButtonPressLightenAmount = 0.06;

typedef _RadioButtonColors = ({Color background, Color border, Color primary});

class AnthemRadioButton extends StatefulWidget {
  final bool selected;
  final VoidCallback? onSelected;
  final String? label;

  const AnthemRadioButton({
    super.key,
    required this.selected,
    this.onSelected,
    this.label,
  });

  @override
  State<AnthemRadioButton> createState() => _AnthemRadioButtonState();
}

class _AnthemRadioButtonState extends State<AnthemRadioButton> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onSelected != null;
    final colors = _resolveColors(
      hovered: interactive && hovered,
      pressed: interactive && pressed,
    );

    final radioButton = SizedBox.square(
      dimension: _radioButtonSize,
      child: CustomPaint(
        painter: _RadioButtonPainter(selected: widget.selected, colors: colors),
      ),
    );

    final content = widget.label == null
        ? radioButton
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              radioButton,
              const SizedBox(width: _radioButtonLabelGap),
              Text(
                widget.label!,
                style: TextStyle(
                  color: AnthemTheme.text.main,
                  fontSize: _radioButtonLabelFontSize,
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToLastDescent: false,
                ),
              ),
            ],
          );

    final onSelected = widget.onSelected;
    if (onSelected == null) {
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
          onTap: onSelected,
          child: content,
        ),
      ),
    );
  }
}

class _RadioButtonPainter extends CustomPainter {
  final bool selected;
  final _RadioButtonColors colors;

  const _RadioButtonPainter({required this.selected, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.fill;
    final backgroundPaint = Paint()
      ..color = colors.background
      ..style = PaintingStyle.fill;
    final primaryPaint = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(center, 8, borderPaint);

    if (!selected) {
      canvas.drawCircle(center, 7, backgroundPaint);
      return;
    }

    canvas.drawCircle(center, 7, primaryPaint);
    canvas.drawCircle(center, 6, backgroundPaint);
    canvas.drawCircle(center, 4, primaryPaint);
  }

  @override
  bool shouldRepaint(covariant _RadioButtonPainter oldDelegate) {
    return oldDelegate.selected != selected || oldDelegate.colors != colors;
  }
}

_RadioButtonColors _resolveColors({
  required bool hovered,
  required bool pressed,
}) {
  final idleColors = (
    background: AnthemTheme.panel.backgroundDark,
    border: AnthemTheme.panel.border,
    primary: AnthemTheme.primary.main,
  );

  if (pressed) {
    return _lightenColors(idleColors, _radioButtonPressLightenAmount);
  }

  if (hovered) {
    return _lightenColors(idleColors, _radioButtonHoverLightenAmount);
  }

  return idleColors;
}

_RadioButtonColors _lightenColors(_RadioButtonColors colors, double amount) {
  return (
    background: _lighten(colors.background, amount),
    border: colors.border,
    primary: _lighten(colors.primary, amount),
  );
}

Color _lighten(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  final lightness = (hsl.lightness + amount).clamp(0.0, 1.0).toDouble();

  return hsl.withLightness(lightness).toColor();
}
