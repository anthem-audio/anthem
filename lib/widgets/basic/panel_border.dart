/*
  Copyright (C) 2025 Joshua Wade

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
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class PanelBorder extends StatelessObserverWidget {
  final PanelKind? panelKind;
  final Widget? child;

  const PanelBorder({super.key, this.panelKind, this.child});

  @override
  Widget build(BuildContext context) {
    final projectId = AnthemStore.instance.activeProjectId;
    final viewModel = ServiceRegistry.forProject(projectId).projectViewModel;

    final isActive = panelKind != null && viewModel.activePanel == panelKind;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive
              ? AnthemTheme.panel.borderLightActive
              : AnthemTheme.panel.borderLight,
          width: 3,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AnthemTheme.panel.border, width: 1),
        ),
        child: Listener(
          onPointerDown: (_) {
            if (panelKind != null) {
              viewModel.activePanel = panelKind;
            }
          },
          child: child,
        ),
      ),
    );
  }
}
