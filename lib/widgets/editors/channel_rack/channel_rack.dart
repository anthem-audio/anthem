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
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/channel_rack/devices/device_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class ChannelRack extends StatefulWidget {
  const ChannelRack({super.key});

  @override
  State<ChannelRack> createState() => _ChannelRackState();
}

class _ChannelRackState extends State<ChannelRack> {
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
      color: AnthemTheme.panel.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
    return _buildAddDeviceButton(context, track.id);
  }

  return Expanded(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final device in track.devices) DeviceView(device: device),
          const SizedBox(width: 8),
          _buildAddDeviceButton(context, track.id, compact: true),
        ],
      ),
    ),
  );
}

Widget _buildAddDeviceButton(
  BuildContext context,
  Id trackId, {
  bool compact = false,
}) {
  final project = Provider.of<ProjectModel>(context, listen: false);
  final serviceRegistry = ServiceRegistry.forProject(project.id);
  final deviceController = serviceRegistry.deviceController;
  final addDeviceMenuController = AnthemMenuController();

  final menuDef = MenuDef(
    children: [
      AnthemMenuItem(
        text: 'Tone Generator',
        onSelected: () {
          deviceController.addDevice(
            trackId: trackId,
            type: DeviceType.toneGenerator,
          );
        },
      ),
      AnthemMenuItem(
        text: 'Utility',
        onSelected: () {
          deviceController.addDevice(
            trackId: trackId,
            type: DeviceType.utility,
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
            );
          },
        ),
    ],
  );

  final button = Menu(
    menuController: addDeviceMenuController,
    menuDef: menuDef,
    child: Button(
      width: compact ? 96 : 120,
      height: 26,
      text: compact ? 'Add' : 'Add Device',
      hint: [HintSection('click', 'Add a device to this track')],
      onPress: () {
        addDeviceMenuController.open();
      },
    ),
  );

  if (compact) {
    return Center(child: button);
  }

  return Expanded(child: Center(child: button));
}
