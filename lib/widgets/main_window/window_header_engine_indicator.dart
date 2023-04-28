/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class EngineIndicator extends StatelessObserverWidget {
  const EngineIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final store = AnthemStore.instance;
    final activeProject = store.projects[store.activeProjectID]!;

    late final Widget indicator;

    if (activeProject.engineState == EngineState.starting) {
      indicator = SizedBox(
        width: 12,
        height: 12,
        child: material.CircularProgressIndicator(
          color: Theme.text.main,
          strokeWidth: 2,
        ),
      );
    } else {
      indicator = SvgIcon(
        icon: Icons.anthem,
        color: activeProject.engineState == EngineState.running
            ? Theme.primary.main
            : Theme.text.main,
      );
    }

    return Container(
      width: 28,
      decoration: BoxDecoration(
        color: Theme.panel.accent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(2),
          bottomLeft: Radius.circular(1),
          bottomRight: Radius.circular(1),
        ),
      ),
      child: Center(
        child: indicator,
      ),
    );
  }
}
