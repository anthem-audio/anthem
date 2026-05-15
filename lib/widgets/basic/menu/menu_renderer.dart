/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'dart:async';
import 'dart:math';

import 'package:anthem/helpers/measure_text.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/menu/menu_positioning.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'menu_model.dart';

class _Constants {
  static const double menuBorderWidth = 1.0;
  static const double submenuArrowWidth = 8.0;
  static const double submenuIndicatorWidth = submenuArrowWidth * 0.75;
  static const double outerPadding = 3.0;
  static const double horizontalInnerPadding = 8.0;
  static const double verticalInnerPadding = 4.0;
  static const double titleToShortcutGap = 14.0;
  static const double trailingSectionGap = horizontalInnerPadding;
  static const double widthSafetyPadding = 1.0;
  static const double fontSize = 11.0;
  static const double separatorPadding = 7.0;
  static const double separatorHeight = 13.0;
  static const double menuItemHeight = 24.0;

  static const Duration hoverOpenDuration = Duration(milliseconds: 500);
  static const Duration hoverCloseDuration = Duration(milliseconds: 500);
}

double _getMenuItemHeight(GenericMenuItem menuItem) {
  return switch (menuItem) {
    AnthemMenuItem() => _Constants.menuItemHeight,
    Separator() => _Constants.separatorHeight,
  };
}

String? _normalizeShortcutLabel(String? shortcutLabel) {
  final normalized = shortcutLabel?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

double _measureMenuTextWidth(BuildContext context, String text) {
  if (text.isEmpty) return 0;

  final textStyle = DefaultTextStyle.of(
    context,
  ).style.merge(const TextStyle(fontSize: _Constants.fontSize));

  return measureText(
    text: text,
    textStyle: textStyle,
    context: context,
  ).width.ceilToDouble();
}

class _MenuLayoutMetrics {
  final double menuWidth;
  final double titleColumnWidth;
  final double shortcutColumnWidth;
  final double submenuIndicatorColumnWidth;
  final bool hasShortcutColumn;
  final bool hasSubmenuColumn;
  final double titleToShortcutGap;
  final double trailingSectionGap;

  const _MenuLayoutMetrics({
    required this.menuWidth,
    required this.titleColumnWidth,
    required this.shortcutColumnWidth,
    required this.submenuIndicatorColumnWidth,
    required this.hasShortcutColumn,
    required this.hasSubmenuColumn,
    required this.titleToShortcutGap,
    required this.trailingSectionGap,
  });
}

_MenuLayoutMetrics _computeMenuLayoutMetrics({
  required BuildContext context,
  required List<GenericMenuItem> children,
  required BoxConstraints constraints,
}) {
  final menuItems = children.whereType<AnthemMenuItem>().toList();

  var maxTitleWidth = 0.0;
  var maxShortcutWidth = 0.0;
  var hasShortcutColumn = false;
  var hasSubmenuColumn = false;

  for (final menuItem in menuItems) {
    maxTitleWidth = max(
      maxTitleWidth,
      _measureMenuTextWidth(context, menuItem.text),
    );

    final shortcutLabel = _normalizeShortcutLabel(menuItem.shortcutLabel);
    if (shortcutLabel != null) {
      hasShortcutColumn = true;
      maxShortcutWidth = max(
        maxShortcutWidth,
        _measureMenuTextWidth(context, shortcutLabel),
      );
    }

    if (menuItem.submenu != null) {
      hasSubmenuColumn = true;
    }
  }

  final horizontalFrameWidth =
      (_Constants.menuBorderWidth +
          _Constants.outerPadding +
          _Constants.horizontalInnerPadding) *
      2;
  var titleToShortcutGap = hasShortcutColumn
      ? _Constants.titleToShortcutGap
      : 0.0;
  var trailingSectionGap = hasSubmenuColumn
      ? _Constants.trailingSectionGap
      : 0.0;
  var submenuIndicatorWidth = hasSubmenuColumn
      ? _Constants.submenuIndicatorWidth
      : 0.0;

  final maxMenuWidth = constraints.maxWidth.isFinite
      ? constraints.maxWidth
      : double.infinity;

  final preferredTextWidth =
      maxTitleWidth + (hasShortcutColumn ? maxShortcutWidth : 0);
  final preferredContentWidth =
      preferredTextWidth +
      titleToShortcutGap +
      trailingSectionGap +
      submenuIndicatorWidth;
  final preferredMenuWidth =
      preferredContentWidth +
      horizontalFrameWidth +
      _Constants.widthSafetyPadding;
  final resolvedMenuWidth = min(preferredMenuWidth, maxMenuWidth);
  final maxContentWidth = max(0.0, resolvedMenuWidth - horizontalFrameWidth);

  final fixedContentWidth =
      titleToShortcutGap + trailingSectionGap + submenuIndicatorWidth;

  if (fixedContentWidth > maxContentWidth) {
    var overflow = fixedContentWidth - maxContentWidth;

    final shortcutGapReduction = min(titleToShortcutGap, overflow);
    titleToShortcutGap -= shortcutGapReduction;
    overflow -= shortcutGapReduction;

    final trailingGapReduction = min(trailingSectionGap, overflow);
    trailingSectionGap -= trailingGapReduction;
    overflow -= trailingGapReduction;

    final submenuReduction = min(submenuIndicatorWidth, overflow);
    submenuIndicatorWidth -= submenuReduction;
  }

  final availableTextWidth = max(
    0.0,
    maxContentWidth -
        titleToShortcutGap -
        trailingSectionGap -
        submenuIndicatorWidth,
  );

  var resolvedTitleWidth = maxTitleWidth;
  var resolvedShortcutWidth = hasShortcutColumn ? maxShortcutWidth : 0.0;

  if (hasShortcutColumn) {
    final textOverflow = max(
      0.0,
      maxTitleWidth + maxShortcutWidth - availableTextWidth,
    );
    final titleReduction = min(textOverflow, maxTitleWidth);

    resolvedTitleWidth -= titleReduction;
    resolvedShortcutWidth = max(
      0.0,
      maxShortcutWidth - (textOverflow - titleReduction),
    );
  } else {
    resolvedTitleWidth = min(maxTitleWidth, availableTextWidth);
  }

  final resolvedContentWidth =
      resolvedTitleWidth +
      resolvedShortcutWidth +
      titleToShortcutGap +
      trailingSectionGap +
      submenuIndicatorWidth;
  final finalMenuWidth = min(
    maxMenuWidth,
    resolvedContentWidth + horizontalFrameWidth,
  );

  return _MenuLayoutMetrics(
    menuWidth: finalMenuWidth,
    titleColumnWidth: resolvedTitleWidth,
    shortcutColumnWidth: resolvedShortcutWidth,
    submenuIndicatorColumnWidth: submenuIndicatorWidth,
    hasShortcutColumn: hasShortcutColumn,
    hasSubmenuColumn: hasSubmenuColumn,
    titleToShortcutGap: titleToShortcutGap,
    trailingSectionGap: trailingSectionGap,
  );
}

class MenuRenderer extends StatefulWidget {
  final MenuDef menu;

  const MenuRenderer({super.key, required this.menu});

  @override
  State<MenuRenderer> createState() => _MenuRendererState();
}

class _MenuRendererState extends State<MenuRenderer> {
  bool isMouseInside = false;

  int? hintId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutMetrics = _computeMenuLayoutMetrics(
          context: context,
          children: widget.menu.children,
          constraints: constraints,
        );

        return MouseRegion(
          onEnter: (event) {
            setState(() {
              isMouseInside = true;
            });
          },
          onExit: (event) {
            setState(() {
              isMouseInside = false;
            });
            if (hintId != null) {
              HintStore.instance.removeHint(hintId!);
              hintId = null;
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AnthemTheme.overlay.background,
              border: Border.all(
                color: AnthemTheme.overlay.border,
                width: _Constants.menuBorderWidth,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ],
            ),
            width: layoutMetrics.menuWidth,
            child: Padding(
              padding: const EdgeInsets.all(_Constants.outerPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.menu.children
                    .map(
                      (child) => _MenuItemRenderer(
                        menuItem: child,
                        layoutMetrics: layoutMetrics,
                        isMouseInMenu: isMouseInside,
                        updateHintId: (id) {
                          if (hintId != null) {
                            HintStore.instance.removeHint(hintId!);
                          }
                          hintId = id;
                        },
                        removeHint: () {
                          if (hintId != null) {
                            HintStore.instance.removeHint(hintId!);
                            hintId = null;
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItemRenderer extends StatefulWidget {
  final GenericMenuItem menuItem;
  final _MenuLayoutMetrics layoutMetrics;
  final bool isMouseInMenu;

  final void Function(int) updateHintId;
  final void Function() removeHint;

  const _MenuItemRenderer({
    required this.menuItem,
    required this.layoutMetrics,
    required this.isMouseInMenu,
    required this.updateHintId,
    required this.removeHint,
  });

  @override
  State<_MenuItemRenderer> createState() => _MenuItemRendererState();
}

class _MenuItemRendererState extends State<_MenuItemRenderer> {
  bool isHovered = false;
  bool get isSubmenuOpen {
    return submenuHandle != null;
  }

  // If there's no open submenu, this is null
  ScreenOverlayHandle? submenuHandle;

  // This will be defined if the user has hovered an item with a submenu but
  // the submenu hasn't opened yet
  Timer? hoverTimer;

  // This will be defined if the user has hovered a different item in this
  // menu, but the open submenu hasn't closed yet
  Timer? submenuCloseTimer;

  @override
  void didUpdateWidget(covariant _MenuItemRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isMouseInMenu &&
        widget.isMouseInMenu &&
        isSubmenuOpen &&
        !isHovered) {
      startSubmenuCloseTimer();
    } else if (oldWidget.isMouseInMenu && !widget.isMouseInMenu) {
      cancelSubmenuCloseTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenOverlayController = Provider.of<ScreenOverlayController>(
      context,
    );

    final height = _getMenuItemHeight(widget.menuItem);

    if (widget.menuItem is AnthemMenuItem) {
      final item = widget.menuItem as AnthemMenuItem;

      final showHoverState =
          isHovered || (isSubmenuOpen && !widget.isMouseInMenu);

      final textColor = showHoverState
          ? AnthemTheme.primary.main
          : item.disabled
          ? AnthemTheme.text.disabled
          : AnthemTheme.text.main;
      final shortcutLabel = _normalizeShortcutLabel(item.shortcutLabel) ?? '';
      final shortcutColor = showHoverState
          ? AnthemTheme.primary.main
          : AnthemTheme.text.disabled;

      final rowChildren = <Widget>[
        SizedBox(
          width: widget.layoutMetrics.titleColumnWidth,
          child: Text(
            item.text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontSize: _Constants.fontSize),
          ),
        ),
      ];

      if (widget.layoutMetrics.hasShortcutColumn) {
        rowChildren.add(
          SizedBox(width: widget.layoutMetrics.titleToShortcutGap),
        );
        rowChildren.add(
          SizedBox(
            width: widget.layoutMetrics.shortcutColumnWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                shortcutLabel,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: shortcutColor,
                  fontSize: _Constants.fontSize,
                ),
              ),
            ),
          ),
        );
      }

      if (widget.layoutMetrics.hasSubmenuColumn) {
        rowChildren.add(
          SizedBox(width: widget.layoutMetrics.trailingSectionGap),
        );
        rowChildren.add(
          SizedBox(
            width: widget.layoutMetrics.submenuIndicatorColumnWidth,
            child: item.submenu == null
                ? const SizedBox()
                : Center(
                    child: ClipPath(
                      clipper: _TriangleClipper(),
                      child: Container(
                        width: _Constants.submenuIndicatorWidth,
                        height: _Constants.submenuArrowWidth,
                        color: textColor,
                      ),
                    ),
                  ),
          ),
        );
      }

      return MouseRegion(
        onEnter: (e) {
          if (item.disabled) return;

          setState(() {
            isHovered = true;
          });

          if (item.submenu != null && !isSubmenuOpen) {
            startHoverTimer(
              screenOverlayController: screenOverlayController,
              item: item,
            );
          }

          if (item.hint != null) {
            widget.updateHintId(
              HintStore.instance.addHint([HintSection('click', item.hint!)]),
            );
          } else {
            widget.removeHint();
          }

          cancelSubmenuCloseTimer();
        },
        onExit: (e) {
          if (item.disabled) return;

          setState(() {
            isHovered = false;
          });
          cancelHoverTimer();
          startSubmenuCloseTimer();
        },
        child: GestureDetector(
          onTap: () {
            if (item.disabled) return;

            item.onSelected?.call();

            if (item.submenu == null) {
              screenOverlayController.clear();
              widget.removeHint();
            } else {
              openSubmenu(
                screenOverlayController: screenOverlayController,
                item: item,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: showHoverState ? AnthemTheme.overlay.menuItemHover : null,
            ),
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _Constants.horizontalInnerPadding,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: rowChildren,
              ),
            ),
          ),
        ),
      );
    }

    if (widget.menuItem is Separator) {
      return SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _Constants.separatorPadding,
            vertical: (_Constants.separatorHeight / 2).floor().toDouble(),
          ),
          child: Container(color: AnthemTheme.overlay.border),
        ),
      );
    }

    return const SizedBox();
  }

  void openSubmenu({
    required ScreenOverlayController screenOverlayController,
    required AnthemMenuItem item,
  }) {
    if (isSubmenuOpen) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final anchorRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    submenuHandle = screenOverlayController.show(
      ScreenOverlayEntry(
        builder: (screenOverlayContext) {
          return MenuPositioned(
            anchorRect: anchorRect,
            horizontalGap: _Constants.horizontalInnerPadding,
            verticalGap: -_Constants.verticalInnerPadding,
            alignTopToAnchor: true,
            child: MenuRenderer(menu: item.submenu!),
          );
        },
      ),
    );
  }

  void startHoverTimer({
    required ScreenOverlayController screenOverlayController,
    required AnthemMenuItem item,
  }) {
    hoverTimer = Timer(_Constants.hoverOpenDuration, () {
      openSubmenu(screenOverlayController: screenOverlayController, item: item);

      hoverTimer = null;
    });
  }

  void cancelHoverTimer() {
    hoverTimer?.cancel();
    hoverTimer = null;
  }

  void startSubmenuCloseTimer() {
    submenuCloseTimer = Timer(_Constants.hoverCloseDuration, () {
      if (submenuHandle != null) {
        submenuHandle!.close();
        setState(() {
          submenuHandle = null;
        });
      }
    });
  }

  void cancelSubmenuCloseTimer() {
    submenuCloseTimer?.cancel();
    submenuCloseTimer = null;
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
