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

import 'dart:async';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:mobx/mobx.dart';

part 'arranger_view_model.g.dart';

// ignore: library_private_types_in_public_api
class ArrangerViewModel = _ArrangerViewModel with _$ArrangerViewModel;

abstract class _ArrangerViewModel with Store {
  @observable
  EditorTool tool = EditorTool.pencil;

  @observable
  double baseTrackHeight;

  // Per-track modifier that is multiplied by baseTrackHeight and clamped to
  // get the actual height for each track
  @observable
  ObservableMap<ID, double> trackHeightModifiers;

  // Vertical scroll position, in pixels. Should not be set directly.
  @observable
  double verticalScrollPosition = 0;

  _ArrangerViewModel({
    required this.baseTrackHeight,
    required this.trackHeightModifiers,
  });

  // Total height of the entire scrollable region
  @computed
  double get scrollAreaHeight =>
      getScrollAreaHeight(baseTrackHeight, trackHeightModifiers);

  // Allows us to observe changes to this value before it hits MobX. Fixes an
  // issue with the vertical scroll animation lagging behind the scrollbar.
  StreamController<void> verticalScrollPositionChanged =
      StreamController.broadcast();
}
