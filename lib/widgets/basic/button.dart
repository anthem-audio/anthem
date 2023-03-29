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
  final bool? expand;
  final EdgeInsets contentPadding;

  final bool? showMenuIndicator;
  final Color? backgroundColor;
  final Color? backgroundHoverColor;
  final Color? backgroundPressColor;
  final bool? hideBorder;
  final BorderRadius? borderRadius;

  final Function? onPress;
  final bool? toggleState;

  const Button({
    Key? key,
    this.variant,
    this.text,
    this.startIcon,
    this.endIcon,
    this.width,
    this.height,
    this.expand,
    this.contentPadding = const EdgeInsets.only(left: 5, right: 5),
    this.showMenuIndicator,
    this.backgroundColor,
    this.backgroundHoverColor,
    this.backgroundPressColor,
    this.hideBorder,
    this.borderRadius,
    this.onPress,
    this.toggleState,
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

    final toggleState = pressed || (widget.toggleState ?? false);

    var backgroundColor = theme.background.getColor(hovered, toggleState);

    if (!hovered && !toggleState && widget.backgroundColor != null) {
      backgroundColor = widget.backgroundColor!;
    }

    if (hovered && !toggleState && widget.backgroundHoverColor != null) {
      backgroundColor = widget.backgroundHoverColor!;
    }

    if (toggleState && widget.backgroundHoverColor != null) {
      backgroundColor = widget.backgroundHoverColor!;
    }

    final textColor = theme.text.getColor(hovered, toggleState);

    final List<Widget> innerRowChildren = [];
    final List<Widget> rowChildren = [];

    final startIconWidget = widget.startIcon != null
        ? SvgIcon(
            icon: widget.startIcon!,
            color: textColor,
          )
        : null;

    final textWidget = widget.text != null
        ? Text(
            widget.text!,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : null;

    final endIconWidget = widget.endIcon != null
        ? SvgIcon(
            icon: widget.endIcon!,
            color: textColor,
          )
        : null;

    if (startIconWidget != null) {
      innerRowChildren.add(startIconWidget);
      if (widget.text != null) {
        innerRowChildren.add(
          const SizedBox(width: 4),
        );
      }
    }

    rowChildren.add(
      Expanded(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: innerRowChildren,
        ),
      ),
    );

    if (textWidget != null) {
      innerRowChildren.add(Expanded(child: textWidget));
    }

    if (endIconWidget != null) {
      rowChildren.addAll(
        [
          const SizedBox(width: 4),
          endIconWidget,
        ],
      );
    }

    final Widget buttonContent;

    final startIconOnly =
        startIconWidget != null && textWidget == null && endIconWidget == null;
    final startAndEndIconOnly =
        startIconWidget != null && textWidget == null && endIconWidget != null;

    // Hack to fix row overflow in some icon button cases
    if (startIconOnly) {
      buttonContent = startIconWidget;
    } else if (startAndEndIconOnly) {
      buttonContent = Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            child: Center(child: startIconWidget),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: Center(child: endIconWidget),
          ),
        ],
      );
    } else {
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: widget.endIcon == null
            ? MainAxisAlignment.spaceAround
            : MainAxisAlignment.spaceBetween,
        children: rowChildren,
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
      cursor: SystemMouseCursors.click,
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
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
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

  void _onPointerDown(PointerEvent e) {
    if (!mounted) return;
    setState(() {
      pressed = true;
    });
  }

  void _onPointerUp(PointerEvent e) {
    if (!mounted) return;
    setState(() {
      pressed = false;
      widget.onPress?.call();
    });
  }
}
