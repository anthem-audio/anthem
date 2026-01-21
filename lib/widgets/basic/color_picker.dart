/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

const squareSize = 15.0;
const padding = 4.0;

class ColorPicker extends StatelessWidget {
  final double hue;
  final AnthemColorPaletteKind palette;
  final void Function(AnthemColorPickerEvent event)? onChange;

  const ColorPicker({
    super.key,
    required this.hue,
    required this.palette,
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    const squareMargin = 1.0;
    const colorCellSize = 18.0;

    final hues = colorPickerHues;

    Widget buildColorCell(double hue, AnthemColorPaletteKind palette) {
      void onPointerUp(PointerEvent e) {
        final event = AnthemColorPickerEvent(hue: hue, palette: palette);

        onChange?.call(event);
      }

      return Listener(
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerUp,
        child: Container(
          margin: const EdgeInsets.all(squareMargin),
          decoration: BoxDecoration(
            color: getColor(hue, palette),
            border: Border.all(color: AnthemTheme.panel.border),
          ),
          width: colorCellSize,
          height: colorCellSize,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AnthemTheme.panel.background,
        border: Border.all(color: AnthemTheme.panel.border),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisSize: .min,
            children: Iterable.generate(hues.length, (colorIndex) {
              final hue = hues[colorIndex];
              return buildColorCell(hue, palette);
            }).followedBy([buildColorCell(0, .grayscale)]).toList(),
          ),
          Row(
            mainAxisSize: .min,
            children:
                <AnthemColorPaletteKind>[
                  .dark,
                  .desaturated,
                  .normal,
                  .bright,
                ].map((value) {
                  return buildColorCell(hue, value);
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class AnthemColorPickerEvent {
  final double hue;
  final AnthemColorPaletteKind palette;

  AnthemColorPickerEvent({required this.hue, required this.palette});
}
