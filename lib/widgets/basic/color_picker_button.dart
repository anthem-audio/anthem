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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/color_picker.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Button that opens a color picker.
class ColorPickerButton extends StatefulWidget {
  final double hue;

  const ColorPickerButton({super.key, required this.hue});

  @override
  State<ColorPickerButton> createState() => _ColorPickerButtonState();
}

class _ColorPickerButtonState extends State<ColorPickerButton> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final contentRenderBox = context.findRenderObject() as RenderBox;
          final overlayPosition = contentRenderBox.localToGlobal(
            Offset(contentRenderBox.size.width, 0),
          );
          final overlayId = getId();

          final screenOverlayController = Provider.of<ScreenOverlayController>(
            context,
            listen: false,
          );

          screenOverlayController.add(
            overlayId,
            ScreenOverlayEntry(
              builder: (context, id) {
                return Positioned(
                  left: overlayPosition.dx,
                  top: overlayPosition.dy,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AnthemTheme.overlay.background,
                      border: Border.all(color: AnthemTheme.overlay.border),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF000000,
                          ).withValues(alpha: 0.25),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: ColorPicker(currentHue: 123),
                  ),
                );
              },
            ),
          );
        },
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: HSLColor.fromAHSL(1.0, widget.hue, 0.5, 0.5).toColor(),
            border: .all(color: AnthemTheme.panel.border),
            borderRadius: .circular(4),
          ),
        ),
      ),
    );
  }
}
