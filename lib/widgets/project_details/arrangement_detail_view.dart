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

import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/text_box_controlled.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class ArrangementDetailView extends StatefulObserverWidget {
  const ArrangementDetailView({super.key});

  @override
  State<ArrangementDetailView> createState() => _ArrangementDetailViewState();
}

class _ArrangementDetailViewState extends State<ArrangementDetailView> {
  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final arrangementID =
        (project.getSelectedDetailView() as ArrangementDetailViewKind)
            .arrangementID;
    final arrangement = project.sequence.arrangements[arrangementID]!;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AnthemTheme.panel.main,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ARRANGEMENT',
                style: TextStyle(color: AnthemTheme.text.main, fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              ControlledTextBox(
                height: 26,
                text: arrangement.name,
                onChange: (text) {
                  project.execute(
                    SetArrangementNameCommand(
                      project: project,
                      arrangementID: arrangementID,
                      newName: text,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AnthemTheme.panel.main,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}
