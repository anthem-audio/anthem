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

import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class FakeFileSelector extends FileSelectorPlatform {
  XFile? selectedFile;
  FileSaveLocation? saveLocation;
  int saveCount = 0;
  SaveDialogOptions? lastSaveOptions;
  String? saveInitialDirectory;
  String? selectedDirectory;

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async => selectedDirectory;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    return selectedFile;
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    saveCount++;
    lastSaveOptions = options;
    saveInitialDirectory = options.initialDirectory;
    return saveLocation;
  }
}

class RecordingDialog extends DialogControllerImpl {
  int shownCount = 0;

  @override
  bool get isOpen => false;

  @override
  void showDialog(
    Widget content, {
    String? title,
    List<DialogButton>? buttons,
    bool dismissible = true,
    ValueListenable<bool>? canDismiss,
    void Function()? onDismiss,
  }) {
    shownCount++;
  }

  @override
  void closeDialog() {}
}
