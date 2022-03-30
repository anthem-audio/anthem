/*
  Copyright (C) 2022 Joshua Wade

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
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:flutter/widgets.dart';

import 'background.dart';
import 'icon.dart';

enum ButtonVariant {
  light,
  dark,
  label,
  ghost,
}

class _ButtonColors {
  late Color base;
  late Color hover;
  late Color press;

  _ButtonColors({
    required this.base,
    required this.hover,
    required this.press,
  });

  _ButtonColors.all(Color color) {
    base = color;
    hover = color;
    press = color;
  }

  Color getColor(bool hovered, bool pressed) {
    if (pressed) return press;
    if (hovered) return hover;
    return base;
  }
}

class _ButtonTheme {
  final _ButtonColors background;
  final _ButtonColors border;
  final _ButtonColors text;

  const _ButtonTheme({
    required this.background,
    required this.border,
    required this.text,
  });
}

final _textColors = _ButtonColors(
  base: const Color(0xFF9DB9CC),
  hover: const Color(0xFF9DB9CC),
  press: const Color(0xFF25C29D),
);

final _lightTheme = _ButtonTheme(
  background: _ButtonColors(
    base: const Color(0xFF4C5A63),
    hover: const Color(0xFF505F69),
    press: const Color(0xFF505F69),
  ),
  border: _ButtonColors.all(
    const Color(0xFF293136),
  ),
  text: _textColors,
);
final _darkTheme = _ButtonTheme(
  background: _ButtonColors(
    base: const Color(0xFF414C54),
    hover: const Color(0xFF455159),
    press: const Color(0xFF455159),
  ),
  border: _ButtonColors.all(
    const Color(0xFF293136),
  ),
  text: _textColors,
);
final _labelTheme = _ButtonTheme(
  background: _ButtonColors(
    base: const Color(0x00000000),
    hover: const Color(0x00000000),
    press: const Color(0x00000000),
  ),
  border: _ButtonColors(
    base: const Color(0x00000000),
    hover: const Color(0xFF293136),
    press: const Color(0xFF293136),
  ),
  text: _textColors,
);
final _ghostTheme = _ButtonTheme(
  background: _ButtonColors(
    base: const Color(0x00000000),
    hover: const Color(0xFF3C484F),
    press: const Color(0xFF3C484F),
  ),
  border: _ButtonColors.all(
    const Color(0xFF293136),
  ),
  text: _textColors,
);

class Button extends StatefulWidget {
  final ButtonVariant? variant;
  final String? text;
  final IconDef? startIcon;
  final IconDef? endIcon;
  final double? width;
  final double? height;
  final bool? showMenuIndicator;
  final Function? onPress;
  final Color? backgroundColor;
  final Color? backgroundHoverColor;
  final Color? backgroundPressColor;
  final bool? hideBorder;
  final bool? expand;
  final EdgeInsets contentPadding;

  const Button({
    Key? key,
    this.variant,
    this.text,
    this.startIcon,
    this.endIcon,
    this.width,
    this.height,
    this.showMenuIndicator,
    this.onPress,
    this.backgroundColor,
    this.backgroundHoverColor,
    this.backgroundPressColor,
    this.hideBorder,
    this.expand,
    this.contentPadding = const EdgeInsets.all(5),
  }) : super(key: key);

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  var hovered = false;
  var pressed = false;

  _ButtonState();

  @override
  Widget build(BuildContext context) {
    _ButtonTheme theme;

    final backgroundType = Provider.of<BackgroundType>(context);

    final variant = widget.variant ??
        (backgroundType == BackgroundType.light
            ? ButtonVariant.light
            : ButtonVariant.dark);

    switch (variant) {
      case ButtonVariant.light:
        theme = _lightTheme;
        break;
      case ButtonVariant.dark:
        theme = _darkTheme;
        break;
      case ButtonVariant.label:
        theme = _labelTheme;
        break;
      case ButtonVariant.ghost:
        theme = _ghostTheme;
        break;
    }

    var backgroundColor = theme.background.getColor(hovered, pressed);

    if (!hovered && !pressed && widget.backgroundColor != null) {
      backgroundColor = widget.backgroundColor!;
    }

    if (hovered && !pressed && widget.backgroundHoverColor != null) {
      backgroundColor = widget.backgroundHoverColor!;
    }

    if (pressed && widget.backgroundHoverColor != null) {
      backgroundColor = widget.backgroundHoverColor!;
    }

    final textColor = theme.text.getColor(hovered, pressed);

    final List<Widget> innerRowChildren = [];
    final List<Widget> rowChildren = [];

    if (widget.startIcon != null) {
      innerRowChildren.add(
        SvgIcon(
          widget.startIcon!,
          color: textColor,
        ),
      );
      if (widget.text != null) {
        innerRowChildren.add(
          const SizedBox(width: 4),
        );
      }
    }

    rowChildren.add(
      Row(
        children: innerRowChildren,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
      ),
    );

    if (widget.text != null) {
      innerRowChildren.add(
        Text(
          widget.text!,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (widget.endIcon != null) {
      rowChildren.addAll(
        [
          const SizedBox(width: 4),
          SvgIcon(
            widget.endIcon!,
            color: textColor,
          ),
        ],
      );
    }

    final Widget buttonContent;

    final iconOnly = widget.startIcon != null && widget.text == null;

    // Hack to fix row overflow in some icon button cases
    if (iconOnly) {
      buttonContent = innerRowChildren[0];
    } else {
      buttonContent = Row(
        children: rowChildren,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: widget.endIcon == null
            ? MainAxisAlignment.spaceAround
            : MainAxisAlignment.spaceBetween,
      );
    }

    final List<Widget> stackChildren = [
      Padding(
        padding: widget.contentPadding,
        child: buttonContent,
      ),
    ];

    if (widget.showMenuIndicator == true) {
      stackChildren.add(
        Positioned(
          right: 0,
          bottom: 0,
          child: Transform(
            transform: Matrix4.rotationZ(pi / 4)..translate(Vector3(8, -4, 0)),
            child: Container(
              width: 6 * sqrt2,
              height: 6 * sqrt2,
              color: textColor,
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (e) {
        if (!mounted) return;
        setState(() {
          hovered = true;
        });
      },
      onExit: (e) {
        if (!mounted) return;
        setState(() {
          hovered = false;
        });
      },
      child: Listener(
        onPointerDown: (e) {
          if (!mounted) return;
          setState(() {
            pressed = true;
          });
        },
        onPointerUp: (e) {
          if (!mounted) return;
          setState(() {
            pressed = false;
            widget.onPress?.call();
          });
        },
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: widget.hideBorder == true
                ? null
                : Border.all(
                    color: theme.border.getColor(hovered, pressed),
                  ),
            color: backgroundColor,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: Stack(
              fit: widget.expand != null
                  ? StackFit.expand
                  : StackFit.passthrough,
              children: stackChildren,
            ),
          ),
        ),
      ),
    );
  }
}
