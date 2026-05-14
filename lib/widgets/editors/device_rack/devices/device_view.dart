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
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/device_rack/devices/tone_generator_device.dart';
import 'package:anthem/widgets/editors/device_rack/devices/utility_device.dart';
import 'package:anthem/widgets/editors/device_rack/devices/vst3_device.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class DeviceView extends StatefulObserverWidget {
  final Id trackId;
  final DeviceModel device;

  const DeviceView({super.key, required this.trackId, required this.device});

  @override
  State<DeviceView> createState() => _DeviceViewState();
}

class _DeviceViewState extends State<DeviceView> {
  final _menuController = AnthemMenuController();

  bool _isHeaderHovered = false;
  bool _isHeaderPressed = false;

  @override
  Widget build(BuildContext context) {
    final child = switch (widget.device.type) {
      DeviceType.toneGenerator => ToneGeneratorDevice(device: widget.device),
      DeviceType.utility => UtilityDevice(device: widget.device),
      DeviceType.vst3Plugin => Vst3Device(device: widget.device),
    };
    final isCollapsed = widget.device.isCollapsed;
    final headerBorderRadius = isCollapsed
        ? BorderRadius.circular(4)
        : BorderRadius.horizontal(left: .circular(4));
    final headerBaseColor = isCollapsed
        ? AnthemTheme.panel.accent
        : AnthemTheme.panel.background;
    final headerBackground = _isHeaderPressed
        ? _adjustGreyLightness(headerBaseColor, -0.02)
        : _isHeaderHovered
        ? _adjustGreyLightness(headerBaseColor, 0.03)
        : headerBaseColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (event) {
            setState(() {
              _isHeaderHovered = true;
            });
          },
          onExit: (event) {
            setState(() {
              _isHeaderHovered = false;
              _isHeaderPressed = false;
            });
          },
          child: Listener(
            onPointerDown: (event) {
              setState(() {
                _isHeaderPressed = true;
              });
            },
            onPointerUp: (event) {
              setState(() {
                _isHeaderPressed = false;
              });
            },
            onPointerCancel: (event) {
              setState(() {
                _isHeaderPressed = false;
              });
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.device.isCollapsed = !widget.device.isCollapsed;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: headerBackground,
                  borderRadius: headerBorderRadius,
                ),
                clipBehavior: Clip.antiAlias,
                width: 32,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  child: Column(
                    children: [
                      _DeviceMenuButton(
                        menuController: _menuController,
                        menuDef: _buildDeviceMenuDef(context),
                      ),
                      Spacer(),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          widget.device.name,
                          style: .new(color: AnthemTheme.text.main),
                        ),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!isCollapsed)
          Container(
            decoration: BoxDecoration(
              color: AnthemTheme.panel.accent,
              borderRadius: BorderRadius.horizontal(right: .circular(4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
      ],
    );
  }

  MenuDef _buildDeviceMenuDef(BuildContext context) {
    final project = Provider.of<ProjectModel>(context, listen: false);
    final deviceController = ServiceRegistry.forProject(
      project.id,
    ).deviceController;

    return MenuDef(
      children: [
        AnthemMenuItem(
          text: 'Delete',
          hint: 'Delete this device',
          onSelected: () {
            deviceController.removeDevice(
              trackId: widget.trackId,
              deviceId: widget.device.id,
            );
          },
        ),
      ],
    );
  }
}

Color _adjustGreyLightness(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);

  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0).toDouble())
      .toColor();
}

class _DeviceMenuButton extends StatelessWidget {
  final AnthemMenuController menuController;
  final MenuDef menuDef;

  const _DeviceMenuButton({
    required this.menuController,
    required this.menuDef,
  });

  @override
  Widget build(BuildContext context) {
    return Menu(
      menuController: menuController,
      menuDef: menuDef,
      child: Button(
        icon: Icons.kebab,
        variant: .label,
        width: 24,
        height: 24,
        onPress: () {
          menuController.open();
        },
      ),
    );
  }
}
