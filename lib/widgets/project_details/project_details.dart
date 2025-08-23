/*
  Copyright (C) 2022 - 2025 Joshua Wade

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
import 'package:anthem/widgets/project_details/arrangement_detail_view.dart';
import 'package:anthem/widgets/project_details/pattern_detail_view.dart';
import 'package:anthem/widgets/project_details/time_signature_change_detail_view.dart';
import 'package:flutter/widgets.dart';

class ProjectDetails extends StatelessWidget {
  final DetailViewKind? selectedProjectDetails;

  const ProjectDetails({super.key, required this.selectedProjectDetails});

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (selectedProjectDetails is PatternDetailViewKind) {
      child = const PatternDetailView();
    } else if (selectedProjectDetails is ArrangementDetailViewKind) {
      child = const ArrangementDetailView();
    } else if (selectedProjectDetails is TimeSignatureChangeDetailViewKind) {
      child = const TimeSignatureChangeDetailView();
    } else {
      child = Container(
        decoration: BoxDecoration(
          color: AnthemTheme.panel.main,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This is the detail view. Click on something to view and edit its details.',
              style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ClipRRect(borderRadius: BorderRadius.circular(4), child: child);
  }
}
