/*
  Copyright (C) 2021 Joshua Wade

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

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../theme.dart';

class Button extends StatefulWidget {
  final VoidCallback? onPress;
  final double? width;
  final double? height;
  final String? iconPath;
  final Widget? child;
  final bool? hideBorder;
  final bool? hideBackground;
  final bool? showMenuIndicator;

  const Button({
    Key? key,
    this.onPress,
    this.width,
    this.height,
    this.iconPath,
    this.child,
    this.hideBorder,
    this.hideBackground,
    this.showMenuIndicator,
  }) : super(key: key);

  @override
  _ButtonState createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = Theme.control.hover;
    final activeColor = Theme.control.active;

    var backgroundColor = widget.hideBackground ?? false
        ? const Color(0x00000000)
        : Theme.control.main;
    if (hovered) backgroundColor = hoverColor;
    if (pressed) backgroundColor = activeColor;

    final showMenuIndicator = widget.showMenuIndicator ?? false;

    return MouseRegion(
      onEnter: (e) {
        setState(() {
          hovered = true;
        });
      },
      onExit: (e) {
        setState(() {
          hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onPress,
        child: Listener(
          onPointerDown: (e) {
            setState(() {
              pressed = true;
            });
          },
          onPointerUp: (e) {
            setState(() {
              pressed = false;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.all(Radius.circular(1)),
              border: widget.hideBorder ?? false
                  ? null
                  : Border.all(color: Theme.control.border),
            ),
            width: widget.width,
            height: widget.height,
            child: ClipRect(
              child: Stack(
                children: <Widget?>[
                  widget.iconPath != null
                      ? Positioned.fill(
                          child: Center(
                            child: SvgPicture.asset(
                              widget.iconPath!,
                              color: Theme.text.main,
                            ),
                          ),
                        )
                      : null,
                  widget.child != null
                      ? Positioned.fill(child: widget.child!)
                      : null,
                  showMenuIndicator
                      ? Positioned(
                          right: 0,
                          bottom: 0,
                          child: Transform(
                            transform: Matrix4.rotationZ(pi / 4)
                              ..translate(Vector3(4 * sqrt2, -2 * sqrt2, 0)),
                            child: Container(
                              width: 4 * sqrt2,
                              height: 4 * sqrt2,
                              color: Theme.text.main,
                            ),
                          ),
                        )
                      : null,
                ].whereType<Widget>().toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
