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

import 'package:anthem/helpers/id.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'screen_overlay_view_model.g.dart';

// ignore: library_private_types_in_public_api
class ScreenOverlayViewModel = _ScreenOverlayViewModel
    with _$ScreenOverlayViewModel;

abstract class _ScreenOverlayViewModel with Store {
  @observable
  ObservableMap<ID, ScreenOverlayEntry> entries = ObservableMap();
}

// ignore: library_private_types_in_public_api
class ScreenOverlayEntry = _ScreenOverlayEntry with _$ScreenOverlayEntry;

abstract class _ScreenOverlayEntry with Store {
  final Widget Function(BuildContext, ID) builder;

  const _ScreenOverlayEntry({required this.builder});
}
