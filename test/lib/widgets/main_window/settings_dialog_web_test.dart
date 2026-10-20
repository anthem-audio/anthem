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

@TestOn('browser')
library;

import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/main_window/settings_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/file_dialog_test_helpers.dart';

void main() {
  test('settings with only a native projects folder are omitted on web', () {
    final recording = RecordingDialog();
    showSettingsDialog(dialogs: DialogController()..initialize(recording));
    expect(recording.shownCount, 0);
  });
}
