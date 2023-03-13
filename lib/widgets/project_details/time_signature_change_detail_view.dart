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

import 'dart:math';

import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/project_details/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class TimeSignatureChangeDetailView extends StatelessObserverWidget {
  const TimeSignatureChangeDetailView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final detailView =
        project.selectedDetailView as TimeSignatureChangeDetailViewKind;

    late TimeSignatureChangeModel timeSignatureChange;
    if (detailView.arrangementID != null) {
      throw UnimplementedError(
          "Time signature changes in arrangements are not supported yet.");
    } else if (detailView.patternID != null) {
      timeSignatureChange = project
          .song.patterns[detailView.patternID]!.timeSignatureChanges
          .firstWhere((change) => change.id == detailView.changeID);
    } else {
      throw Exception(
          "Invalid TimeSignatureChangeDetailViewKind - it should specify an arrangement ID or pattern ID, but it specified neither.");
    }

    return Column(
      children: [
        Section(
          title: "TIME SIGNATURE CHANGE",
          children: [
            Dropdown(
              height: 26,
              allowNoSelection: false,
              selectedID:
                  timeSignatureChange.timeSignature.numerator.toString(),
              items: List.generate(
                32,
                (index) => DropdownItem(
                  id: (index + 1).toString(),
                  name: (index + 1).toString(),
                ),
              ),
              onChanged: (id) {
                project.execute(
                  SetTimeSignatureNumeratorCommand(
                    project: project,
                    patternID: detailView.patternID,
                    arrangementID: detailView.arrangementID,
                    changeID: detailView.changeID,
                    numerator: int.parse(id!),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Dropdown(
              height: 26,
              allowNoSelection: false,
              selectedID:
                  timeSignatureChange.timeSignature.numerator.toString(),
              items: List.generate(
                6,
                (index) {
                  final value = pow(2, index).toString();
                  return DropdownItem(id: value, name: value);
                },
              ),
              onChanged: (id) {
                project.execute(
                  SetTimeSignatureDenominatorCommand(
                    project: project,
                    patternID: detailView.patternID,
                    arrangementID: detailView.arrangementID,
                    changeID: detailView.changeID,
                    denominator: int.parse(id!),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Expanded(child: SizedBox()),
      ],
    );
  }
}
