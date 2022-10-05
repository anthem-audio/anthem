/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:anthem/widgets/project_details/arrangement_detail_view.dart';
import 'package:anthem/widgets/project_details/pattern_detail_view.dart';
import 'package:anthem/widgets/project_details/pattern_detail_view_cubit.dart';
import 'package:anthem/widgets/project_details/time_signature_change_detail_view.dart';
import 'package:anthem/widgets/project_details/time_signature_change_detail_view_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'arrangement_detail_view_cubit.dart';

class ProjectDetails extends StatelessWidget {
  final DetailViewKind? selectedProjectDetails;

  const ProjectDetails({
    Key? key,
    required this.selectedProjectDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final projectCubit = Provider.of<ProjectCubit>(context);

    if (selectedProjectDetails is PatternDetailViewKind) {
      return BlocProvider(
        create: (context) =>
            PatternDetailViewCubit(projectID: projectCubit.project.id),
        child: const PatternDetailView(),
      );
    } else if (selectedProjectDetails is ArrangementDetailViewKind) {
      return BlocProvider(
        create: (context) => ArrangementDetailViewCubit(
          projectID: projectCubit.project.id,
        ),
        child: const ArrangementDetailView(),
      );
    } else if (selectedProjectDetails is TimeSignatureChangeDetailViewKind) {
      return BlocProvider(
        create: (context) => TimeSignatureChangeDetailViewCubit(
          projectID: projectCubit.project.id,
        ),
        child: const TimeSignatureChangeDetailView(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.panel.main,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "This is the detail view. Click on something to view and edit its details.",
            style: TextStyle(
              color: Theme.text.main,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
