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
import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

class Vst3Device extends StatelessWidget {
  final DeviceModel device;

  const Vst3Device({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Text(
            device.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
