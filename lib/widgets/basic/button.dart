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

import 'dart:math';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:flutter/widgets.dart';

import 'icon.dart';

enum ButtonVariant { main, label, ghost }

class _ButtonColors {
  final Color idle;
  final Color hover;
  final Color press;
  final Color toggleActive;

  const _ButtonColors({
    required this.idle,
    required this.hover,
    required this.press,
    required this.toggleActive,
  });

  const _ButtonColors.all(Color color)
    : this(idle: color, hover: color, press: color, toggleActive: color);

  Color getColor(bool hovered, bool pressed, bool toggled) {
    if (toggled) return toggleActive;
    if (pressed) return press;
    if (hovered) return hover;
    return idle;
  }
}

class _ButtonTheme {
  final _ButtonColors background;
  final _ButtonColors border;
  final _ButtonColors content;

  const _ButtonTheme({
    required this.background,
    required this.border,
    required this.content,
  });
}

final _textColors = _ButtonColors(
  idle: Color(0xFFCFCFCF),
  hover: Color(0xFFEFEFEF),
  press: Color(0xFFAFAFAF),
  toggleActive: AnthemTheme.primary.main,
);

final _mainTheme = _ButtonTheme(
  background: const _ButtonColors(
    idle: Color(0xFF5E5E5E),
    hover: Color(0xFF686868),
    press: Color(0xFF4E4E4E),
    toggleActive: Color(0xFF3B3B3B),
  ),
  border: const _ButtonColors.all(Color(0xFF2F2F2F)),
  content: _textColors,
);
final _labelTheme = _ButtonTheme(
  background: _ButtonColors.all(const Color(0x00000000)),
  border: _ButtonColors(
    idle: const Color(0x00000000),
    hover: const Color(0xFF2F2F2F),
    press: const Color(0xFF2F2F2F),
    toggleActive: const Color(0xFF2F2F2F),
  ),
  content: _textColors,
);
final _ghostTheme = _ButtonTheme(
  background: const _ButtonColors(
    idle: Color(0x00000000),
    hover: Color(0xFF464646),
    press: Color(0xFF464646),
    toggleActive: Color(0xFF464646),
  ),
  border: _ButtonColors.all(const Color(0xFF2F2F2F)),
  content: _textColors,
);

class Button extends StatefulWidget {
  final ButtonVariant? variant;

  final String? text;
  final IconDef? icon;

  final Widget Function(BuildContext context, Color contentColor)?
  contentBuilder;

  final double? width;
  final double? height;
  final bool? expand;
  final EdgeInsets contentPadding;

  final bool? showMenuIndicator;
  final Color? background;
  final Color? backgroundHover;
  final Color? backgroundPress;
  final Color? backgroundToggleActive;
  final bool? hideBorder;
  final BorderRadius? borderRadius;

  final Function? onPress;
  final bool? toggleState;

  final List<HintSection>? hint;

  const Button({
    super.key,
    this.variant,
    this.text,
    this.icon,
    this.contentBuilder,
    this.width,
    this.height,
    this.expand,
    this.contentPadding = const EdgeInsets.only(left: 3, right: 3),
    this.showMenuIndicator,
    this.background,
    this.backgroundHover,
    this.backgroundPress,
    this.backgroundToggleActive,
    this.hideBorder,
    this.borderRadius,
    this.onPress,
    this.toggleState,
    this.hint,
  });

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  var hovered = false;
  var pressed = false;

  int? hintId;

  _ButtonState();

  @override
  void dispose() {
    if (hintId != null) {
      HintStore.instance.removeHint(hintId!);
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(Button oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (hovered && oldWidget.hint != widget.hint) {
      if (hintId != null) {
        HintStore.instance.removeHint(hintId!);
      }

      if (widget.hint != null) {
        hintId = HintStore.instance.addHint(widget.hint!);
      } else {
        hintId = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _ButtonTheme theme;

    final variant = widget.variant ?? ButtonVariant.main;

    switch (variant) {
      case ButtonVariant.main:
        theme = _mainTheme;
        break;
      case ButtonVariant.label:
        theme = _labelTheme;
        break;
      case ButtonVariant.ghost:
        theme = _ghostTheme;
        break;
    }

    final toggled = (widget.toggleState ?? false);

    var background = theme.background.getColor(hovered, pressed, toggled);

    if (!hovered && !pressed && !toggled && widget.background != null) {
      background = widget.background!;
    }

    if (hovered && !pressed && !toggled && widget.backgroundHover != null) {
      background = widget.backgroundHover!;
    }

    if (pressed && !toggled && widget.backgroundPress != null) {
      background = widget.backgroundPress!;
    }

    if (toggled && widget.backgroundToggleActive != null) {
      background = widget.backgroundToggleActive!;
    }

    final contentColor = theme.content.getColor(hovered, pressed, toggled);

    Widget? buttonContent;

    if (widget.contentBuilder != null) {
      buttonContent = widget.contentBuilder!(context, contentColor);
    } else if (widget.text != null) {
      buttonContent = Center(
        child: Text(
          widget.text!,
          style: TextStyle(
            color: contentColor,
            fontSize: 11,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else if (widget.icon != null) {
      buttonContent = SvgIcon(icon: widget.icon!, color: contentColor);
    }

    final List<Widget> stackChildren = [
      Padding(padding: widget.contentPadding, child: buttonContent),
    ];

    if (widget.showMenuIndicator == true) {
      stackChildren.add(
        Positioned(
          right: 0,
          bottom: 0,
          child: Transform(
            transform: Matrix4.rotationZ(pi / 4)
              ..translateByVector3(Vector3(8, -4, 0)),
            child: Container(
              width: 6 * sqrt2,
              height: 6 * sqrt2,
              color: contentColor,
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
        if (widget.hint != null) {
          hintId = HintStore.instance.addHint(widget.hint!);
        }
      },
      onExit: (e) {
        if (!mounted) return;
        setState(() {
          hovered = false;
        });
        if (widget.hint != null && hintId != null) {
          HintStore.instance.removeHint(hintId!);
        }
      },
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: (e) => _onPointerUp(e, true),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            border: widget.hideBorder == true
                ? null
                : Border.all(
                    color: theme.border.getColor(hovered, pressed, toggled),
                  ),
            color: background,
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

  void _onPointerUp(PointerEvent e, [bool cancelled = false]) {
    if (!mounted) return;

    setState(() {
      pressed = false;
    });

    if (hovered && !cancelled) {
      widget.onPress?.call();
    }
  }
}
