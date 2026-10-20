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

import 'dart:async';

import 'package:anthem/logic/application_settings.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _log = Logger('settings_dialog');

typedef ProjectsDirectoryChooser = Future<String?> Function(
  String? initialDirectory,
);

/// Owns a settings draft for one dialog. Only [save] changes preferences.
class SettingsDialogController extends ChangeNotifier {
  final ApplicationSettings settings;
  final ProjectsDirectoryChooser _chooseDirectory;
  final _canDismiss = ValueNotifier(true);
  bool _disposed = false;
  String? _savedOverride;
  String? _customProjectsDirectory;

  bool isLoading = true;
  bool isLoaded = false;
  bool isSaving = false;
  bool isChoosing = false;
  bool isUsingSystemDefault = true;
  String? defaultProjectsDirectory;
  String? error;

  SettingsDialogController(
    this.settings, {
    ProjectsDirectoryChooser? chooseDirectory,
  }) : _chooseDirectory = chooseDirectory ?? _pickDirectory;

  ValueListenable<bool> get canDismiss => _canDismiss;
  bool get isBusy => isLoading || isSaving || isChoosing;
  bool get canSave =>
      isLoaded &&
      !isBusy &&
      (isUsingSystemDefault || _customProjectsDirectory != null);
  String? get projectsDirectoryOverride =>
      isUsingSystemDefault ? null : _customProjectsDirectory;
  String? get projectsDirectory => isUsingSystemDefault
      ? defaultProjectsDirectory
      : _customProjectsDirectory;

  static Future<String?> _pickDirectory(String? initialDirectory) =>
      getDirectoryPath(
        initialDirectory: initialDirectory,
        confirmButtonText: 'Choose folder',
      );

  Future<void> load() async {
    if (_disposed) return;
    isLoading = true;
    error = null;
    _emit();
    try {
      final (directoryOverride, defaultDirectory) = await (
        settings.projectsDirectoryOverride,
        settings.defaultProjectsDirectory,
      ).wait;
      if (_disposed) return;

      _savedOverride = directoryOverride;
      _customProjectsDirectory = directoryOverride;
      isUsingSystemDefault = directoryOverride == null;
      defaultProjectsDirectory = defaultDirectory;
      isLoaded = true;
    } catch (exception, stackTrace) {
      _log.warning(
        'Could not load application settings.',
        exception,
        stackTrace,
      );
      if (!_disposed) error = 'Could not load settings. Try again.';
    } finally {
      isLoading = false;
      _emit();
    }
  }

  Future<void> browse() async {
    if (_disposed || isBusy || !isLoaded || isUsingSystemDefault) return;
    isChoosing = true;
    error = null;
    _emit();
    try {
      final selected = await _chooseDirectory(
        _customProjectsDirectory ?? defaultProjectsDirectory,
      );
      if (_disposed || selected == null) return;
      if (!path.isAbsolute(selected)) {
        throw ArgumentError('Expected an absolute folder path.');
      }
      _customProjectsDirectory = path.normalize(selected);
    } catch (exception, stackTrace) {
      _log.warning(
        'Could not choose a projects folder.',
        exception,
        stackTrace,
      );
      if (!_disposed) error = 'Could not choose a folder. Try again.';
    } finally {
      isChoosing = false;
      _emit();
    }
  }

  void useDefault() {
    if (_disposed || isBusy || !isLoaded) return;
    isUsingSystemDefault = true;
    error = null;
    _emit();
  }

  void useCustom() {
    if (_disposed || isBusy || !isLoaded) return;
    isUsingSystemDefault = false;
    error = null;
    _emit();
  }

  Future<bool> save() async {
    if (_disposed || !canSave) return false;
    if (projectsDirectoryOverride == _savedOverride) return true;
    isSaving = true;
    error = null;
    _emit();
    try {
      await settings.setProjectsDirectoryOverride(projectsDirectoryOverride);
      if (_disposed) return false;
      _savedOverride = projectsDirectoryOverride;
      return true;
    } catch (exception, stackTrace) {
      _log.warning(
        'Could not save application settings.',
        exception,
        stackTrace,
      );
      if (!_disposed) {
        error =
            'Could not save settings. Your changes are still here; try again.';
      }
      return false;
    } finally {
      isSaving = false;
      _emit();
    }
  }

  void _emit() {
    if (_disposed) return;
    _canDismiss.value = !isSaving && !isChoosing;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _canDismiss.dispose();
    super.dispose();
  }
}
