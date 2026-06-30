/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/main_window/render_dialog.dart';
import 'package:flutter/widgets.dart';

class RenderDialogWidgetTestScreen extends StatefulWidget {
  const RenderDialogWidgetTestScreen({super.key});

  @override
  State<RenderDialogWidgetTestScreen> createState() =>
      _RenderDialogWidgetTestScreenState();
}

class _RenderDialogWidgetTestScreenState
    extends State<RenderDialogWidgetTestScreen> {
  late final ProjectModel _project;

  @override
  void initState() {
    super.initState();

    _project = ProjectModel.create()
      ..filePath = r'C:\Users\example\Music\anthem-demo.anthem';

    final arrangement =
        _project.sequence.arrangements[_project.sequence.activeArrangementID]!;
    final pattern = PatternModel(
      idAllocator: _project.idAllocator,
      name: 'Render preview',
    )..clipAutoWidth = 768;

    _project.sequence.patterns[pattern.id] = pattern;
    arrangement.clips[1] = ClipModel(
      idAllocator: _project.idAllocator,
      patternId: pattern.id,
      trackId: _project.trackOrder.first,
      offset: 192,
      timeView: TimeViewModel(start: 0, end: 576),
    );
    arrangement.loopPoints = LoopPointsModel(192, 768);

    final store = AnthemStore.instance;
    store.projects[_project.id] = _project;
    store.projectOrder.add(_project.id);
    store.activeProjectId = _project.id;
    ServiceRegistry.initializeProject(_project);
  }

  @override
  void dispose() {
    final store = AnthemStore.instance;
    ServiceRegistry.removeProject(_project.id);
    _project.dispose();
    store.projects.remove(_project.id);
    store.projectOrder.remove(_project.id);
    if (store.activeProjectId == _project.id) {
      store.activeProjectId = store.projectOrder.firstOrNull ?? '';
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AnthemTheme.panel.backgroundDark,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AnthemTheme.panel.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              'Render',
              style: TextStyle(
                color: AnthemTheme.text.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(height: 1, color: AnthemTheme.panel.border),
            RenderDialog(projectId: _project.id),
          ],
        ),
      ),
    );
  }
}
