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

import 'package:mobx/mobx.dart';

import '../shared/helpers/types.dart';

part 'view_model.g.dart';

// ignore: library_private_types_in_public_api
class AutomationEditorViewModel = _AutomationEditorViewModel
    with _$AutomationEditorViewModel;

abstract class _AutomationEditorViewModel with Store {
  TimeRange timeView;

  _AutomationEditorViewModel({required this.timeView});
}
