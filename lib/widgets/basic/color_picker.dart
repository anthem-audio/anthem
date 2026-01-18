/*
  Copyright (C) 2022 - 2025 Joshua Wade

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
const squareMargin = 1.0;
const padding = 4.0;

class ColorPicker extends StatefulWidget {
  final double currentHue;
  final void Function(AnthemColorPickerEvent event)? onChange;

  const ColorPicker({super.key, required this.currentHue, this.onChange});

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  @override
  Widget build(BuildContext context) {
    const hueArrayLength = 10;
    const colorCellSpacing = 2.0;

    final hues =
        [0.0] + List.generate(hueArrayLength, (i) => i * 360 / hueArrayLength);

    Widget buildColorCell(double hue, AnthemColorPaletteKind paletteKind) {
      void onPointerUp(PointerEvent e) {
        final event = AnthemColorPickerEvent(hue: hue, paletteKind: .normal);

        widget.onChange?.call(event);
      }

      return Listener(
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerUp,
        child: Container(
          margin: const EdgeInsets.all(squareMargin),
          color: HSLColor.fromAHSL(
            1.0,
            hue,
            switch (paletteKind) {
              AnthemColorPaletteKind.normal => 0.5,
              AnthemColorPaletteKind.bright => 0.5,
              AnthemColorPaletteKind.dark => 0.5,
              AnthemColorPaletteKind.desaturated => 0.2,
              AnthemColorPaletteKind.grayscale => 0.0,
            },
            switch (paletteKind) {
              AnthemColorPaletteKind.normal => 0.5,
              AnthemColorPaletteKind.bright => 0.75,
              AnthemColorPaletteKind.dark => 0.25,
              AnthemColorPaletteKind.desaturated => 0.5,
              AnthemColorPaletteKind.grayscale => 0.5,
            },
          ).toColor(),
          width: 16,
          height: 16,
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
        spacing: colorCellSpacing,
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            spacing: colorCellSpacing,
            mainAxisSize: .min,
            children: Iterable.generate(hues.length, (colorIndex) {
              final hue = hues[colorIndex];
              return buildColorCell(hue, .normal);
            }).followedBy([buildColorCell(0, .grayscale)]).toList(),
          ),
          Row(
            spacing: colorCellSpacing,
            mainAxisSize: .min,
            children:
                <AnthemColorPaletteKind>[
                  .dark,
                  .normal,
                  .bright,
                  .desaturated,
                ].map((value) {
                  return buildColorCell(0, value);
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class AnthemColorPickerEvent {
  final double hue;
  final AnthemColorPaletteKind paletteKind;

  AnthemColorPickerEvent({required this.hue, required this.paletteKind});
}
