/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'project_view_model.g.dart';

enum EditorKind {
  detail,
  automation,
  channelRack,
  mixer,
}

// ignore: library_private_types_in_public_api
class ProjectViewModel = _ProjectViewModel with _$ProjectViewModel;

abstract class _ProjectViewModel with Store {
  @observable
  String hintText = '';

  @observable
  EditorKind selectedEditor = EditorKind.detail;

  // As of writing, MobX generates invalid codegen for the valid type here, which is:
  // Widget Function(BuildContext context)?
  @observable
  dynamic topPanelOverlayContentBuilder;

  void setTopPanelOverlay(Widget Function(BuildContext context)? overlay) {
    topPanelOverlayContentBuilder = overlay;
  }

  void clearTopPanelOverlay() {
    topPanelOverlayContentBuilder = null;
  }
}
