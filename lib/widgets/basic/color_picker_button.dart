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
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/color_picker.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

var _nextColorPickerOverlayId = 0;

Id _allocateColorPickerOverlayId() {
  return _nextColorPickerOverlayId++;
}

/// Button that opens a color picker.
class ColorPickerButton extends StatefulWidget {
  /// Function that must return the current color values for the color picker.
  ///
  /// This is a hack to allow the overlay to observe relevant model changes. It
  /// is expected that getValues() will derive from the relevant MobX models, so
  /// calling it in an observer will subscribe to relevant state.
  final (double hue, AnthemColorPaletteKind palette) Function() getValues;

  final void Function(double hue, AnthemColorPaletteKind palette)? onChange;

  const ColorPickerButton({super.key, required this.getValues, this.onChange});

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
          final overlayId = _allocateColorPickerOverlayId();

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
                    child: Observer(
                      builder: (context) {
                        final (hue, palette) = widget.getValues();

                        return ColorPicker(
                          hue: hue,
                          palette: palette == .grayscale ? .normal : palette,
                          onChange: (e) {
                            widget.onChange?.call(e.hue, e.palette);
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
        child: Observer(
          builder: (context) {
            final (hue, palette) = widget.getValues();

            return Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: getColor(hue, palette),
                border: .all(color: AnthemTheme.panel.border),
                borderRadius: .circular(4),
              ),
            );
          },
        ),
      ),
    );
  }
}
