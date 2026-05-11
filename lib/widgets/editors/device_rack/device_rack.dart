/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/hint/hint.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/device_rack/devices/device_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class DeviceRack extends StatefulWidget {
  const DeviceRack({super.key});

  @override
  State<DeviceRack> createState() => _DeviceRackState();
}

class _DeviceRackState extends State<DeviceRack> {
  @override
  Widget build(BuildContext context) {
    return _DeviceList();
  }
}

class _DeviceList extends StatefulObserverWidget {
  const _DeviceList();

  @override
  State<_DeviceList> createState() => __DeviceListState();
}

class __DeviceListState extends State<_DeviceList> {
  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final arrangerViewModel = serviceRegistry.arrangerViewModel;

    final activeTrackId = arrangerViewModel.selectedTracks.firstOrNull;

    if (activeTrackId == null) {
      return Container(
        color: AnthemTheme.panel.background,
        child: Center(
          child: Text(
            'No track selected',
            style: TextStyle(color: AnthemTheme.text.main),
          ),
        ),
      );
    }

    return Container(
      color: AnthemTheme.panel.border,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
        child: Row(children: [_buildRack(context, project, activeTrackId)]),
      ),
    );
  }
}

Widget _buildRack(
  BuildContext context,
  ProjectModel project,
  Id activeTrackId,
) {
  final track = project.tracks[activeTrackId];

  if (track == null) {
    return const Text('Invalid track');
  }

  if (track.devices.isEmpty) {
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_AddButton(trackId: track.id, index: 0)],
        ),
      ),
    );
  }

  return Expanded(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AddButton(trackId: track.id, index: 0),
          for (final (index, device) in track.devices.indexed) ...[
            DeviceView(
              key: ValueKey(device.id),
              trackId: track.id,
              device: device,
            ),
            _AddButton(trackId: track.id, index: index + 1),
          ],
          const SizedBox(width: 8),
        ],
      ),
    ),
  );
}

MenuDef _buildAddDeviceMenuDef(BuildContext context, Id trackId, int index) {
  final project = Provider.of<ProjectModel>(context, listen: false);
  final serviceRegistry = ServiceRegistry.forProject(project.id);
  final deviceController = serviceRegistry.deviceController;

  return MenuDef(
    children: [
      AnthemMenuItem(
        text: 'Tone Generator',
        onSelected: () {
          deviceController.addDevice(
            trackId: trackId,
            type: DeviceType.toneGenerator,
            index: index,
          );
        },
      ),
      AnthemMenuItem(
        text: 'Utility',
        onSelected: () {
          deviceController.addDevice(
            trackId: trackId,
            type: DeviceType.utility,
            index: index,
          );
        },
      ),
      if (!kIsWeb) Separator(),
      if (!kIsWeb)
        AnthemMenuItem(
          text: 'VST3...',
          onSelected: () {
            deviceController.addDevice(
              trackId: trackId,
              type: DeviceType.vst3Plugin,
              index: index,
            );
          },
        ),
    ],
  );
}

class _AddButton extends StatefulWidget {
  final Id trackId;
  final int index;

  const _AddButton({required this.trackId, required this.index});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  final AnthemMenuController _menuController = AnthemMenuController();

  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Menu(
      menuController: _menuController,
      menuDef: _buildAddDeviceMenuDef(context, widget.trackId, widget.index),
      child: Hint(
        hint: [.new('click', 'Add a device to this track')],
        child: MouseRegion(
          onEnter: (e) {
            setState(() {
              _isHovered = true;
            });
          },
          onExit: (e) {
            setState(() {
              _isHovered = false;
            });
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              _menuController.open(details.globalPosition);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _isHovered
                      ? const Color(0x07FFFFFF)
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                width: 15,
                child: Center(
                  child: SvgIcon(
                    icon: Icons.add,
                    color: _isHovered
                        ? AnthemTheme.text.accent
                        : AnthemTheme.text.main,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
