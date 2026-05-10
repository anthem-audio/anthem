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

import 'package:anthem/model/device.dart';
import 'package:anthem/widgets/editors/device_rack/devices/tone_generator_device.dart';
import 'package:anthem/widgets/editors/device_rack/devices/utility_device.dart';
import 'package:anthem/widgets/editors/device_rack/devices/vst3_device.dart';
import 'package:flutter/widgets.dart';

class DeviceView extends StatelessWidget {
  final DeviceModel device;

  const DeviceView({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return switch (device.type) {
      DeviceType.toneGenerator => ToneGeneratorDevice(device: device),
      DeviceType.utility => UtilityDevice(device: device),
      DeviceType.vst3Plugin => Vst3Device(device: device),
    };
  }
}
