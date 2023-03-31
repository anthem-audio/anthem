/*
  Copyright (C) 2022 - 2023 Joshua Wade

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

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/color_picker.dart';
import 'package:anthem/widgets/basic/text_box_controlled.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'widgets.dart';

class PatternDetailView extends StatelessObserverWidget {
  const PatternDetailView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final patternID =
        (project.selectedDetailView as PatternDetailViewKind).patternID;
    final pattern = project.song.patterns[patternID]!;

    return Column(
      children: [
        Section(
          title: 'PATTERN',
          children: [
            SizedBox(
              height: 26,
              child: ControlledTextBox(
                text: pattern.name,
                onChange: (newName) {
                  project.execute(
                    SetPatternNameCommand(
                      project: project,
                      patternID: patternID,
                      newName: newName,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            ColorPicker(
              onChange: (color) {
                project.execute(
                  SetPatternColorCommand(
                    project: project,
                    patternID: patternID,
                    newColor: color,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.panel.main,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}
