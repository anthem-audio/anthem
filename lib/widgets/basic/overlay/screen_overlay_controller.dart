/*
  Copyright (C) 2023 - 2026 Joshua Wade

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
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';

class ScreenOverlayHandle {
  final ScreenOverlayController _controller;
  final Id _id;

  const ScreenOverlayHandle._(this._controller, this._id);

  void close() {
    _controller._removeById(_id);
  }
}

class ScreenOverlayController {
  ScreenOverlayViewModel viewModel;
  Id _nextOverlayId = 0;

  ScreenOverlayController({required this.viewModel});

  ScreenOverlayHandle show(ScreenOverlayEntry entry) {
    final id = _nextOverlayId++;
    viewModel.entries[id] = entry;
    return ScreenOverlayHandle._(this, id);
  }

  void _removeById(Id id) {
    final entry = viewModel.entries.remove(id);
    entry?.onClose?.call();
  }

  void clear() {
    for (final entry in viewModel.entries.nonObservableInner.values) {
      entry.onClose?.call();
    }

    viewModel.entries.clear();
  }
}
