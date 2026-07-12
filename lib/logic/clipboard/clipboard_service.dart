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

import 'package:anthem/logic/clipboard/clipboard_data.dart';
import 'package:mobx/mobx.dart';

final class ClipboardService {
  final Observable<ClipboardContent?> _data = Observable<ClipboardContent?>(
    null,
  );

  Observable<ClipboardContent?> get data => _data;

  ClipboardContent? get value => _data.value;

  set value(ClipboardContent? content) {
    _data.value = content;
  }

  bool get hasData => value != null;

  bool has<T extends ClipboardContent>() {
    return value is T;
  }

  T? get<T extends ClipboardContent>() {
    final content = value;
    if (content is T) {
      return content;
    }

    return null;
  }

  void set(ClipboardContent content) {
    value = content;
  }

  void clear() {
    if (value == null) {
      return;
    }

    value = null;
  }
}
