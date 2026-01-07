/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

part 'main_window_view_model.g.dart';

// ignore: library_private_types_in_public_api
class MainWindowViewModel = _MainWindowViewModel with _$MainWindowViewModel;

abstract class _MainWindowViewModel with Store {
  /// Overrides the mouse cursor for the entire app.
  ///
  /// Defaults to [MouseCursor.defer], which means no cursor will be set at the
  /// global level.
  @observable
  MouseCursor globalCursor = MouseCursor.defer;
}
