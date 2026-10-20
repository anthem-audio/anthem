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
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/widgets/basic/dialog/dialog_renderer.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay.dart';
import 'package:anthem/widgets/main_window/settings_dialog.dart';
import 'package:anthem/widgets/main_window/settings_dialog_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _browse = find.byKey(const ValueKey('projects-directory-browse'));
final _mode = find.byKey(const ValueKey('projects-directory-mode'));

class _Settings extends ApplicationSettings {
  String? directory = '/custom/projects';
  bool failLoad = false;
  bool failSave = false;
  int writes = 0;
  Completer<void>? saving;

  _Settings() : super(SharedPreferencesAsync());

  @override
  Future<String?> get projectsDirectoryOverride async {
    if (failLoad) throw StateError('Storage unavailable');
    return directory;
  }

  @override
  Future<String?> get defaultProjectsDirectory async =>
      '/documents/Anthem/Projects';

  @override
  Future<void> setProjectsDirectoryOverride(String? value) async {
    writes++;
    await saving?.future;
    if (failSave) throw StateError('Storage unavailable');
    directory = value;
  }
}

void main() {
  setUp(() {
    final original = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
  });

  for (final dismiss in ['Cancel', 'Escape']) {
    testWidgets(
      '$dismiss discards the draft and reopening restores saved settings',
      (tester) async {
        final settings = _Settings();
        await _open(tester, settings);
        await _selectMode(tester, 'Default');
        expect(
          find.text('System default (/documents/Anthem/Projects)'),
          findsOneWidget,
        );
        expect(settings.writes, 0);
        if (dismiss == 'Escape') {
          await tester.tap(_mode);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tap(find.text('Cancel'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Project folder'), findsNothing);
        expect(settings.directory, '/custom/projects');
        await _open(tester, settings);
        expect(find.text('/custom/projects'), findsOneWidget);
      },
    );
  }

  testWidgets('saving waits for persistence and blocks dismissal', (
    tester,
  ) async {
    final settings = _Settings()..saving = Completer<void>();
    await _open(tester, settings);
    await _selectMode(tester, 'Default');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tapAt(const Offset(1, 1));
    await tester.pump();
    expect(find.text('Project folder'), findsOneWidget);
    settings.saving!.complete();
    await tester.pumpAndSettle();
    expect(settings.directory, isNull);
    expect(settings.writes, 1);
    expect(find.text('Project folder'), findsNothing);
  });

  testWidgets('a failed save keeps the draft for retry', (tester) async {
    final settings = _Settings()..failSave = true;
    await _open(tester, settings);
    await _selectMode(tester, 'Default');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save settings.'), findsOneWidget);
    expect(settings.directory, '/custom/projects');
    settings.failSave = false;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.directory, isNull);
    expect(settings.writes, 2);
    expect(find.text('Project folder'), findsNothing);
  });

  testWidgets('failed loading offers retry and prevents saving', (
    tester,
  ) async {
    final settings = _Settings()..failLoad = true;
    await _open(tester, settings);
    expect(find.text('Could not load settings. Try again.'), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(settings.writes, 0);
    settings.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('/custom/projects'), findsOneWidget);
  });

  testWidgets(
    'the picker blocks dismissal and only saves a chosen folder on Save',
    (tester) async {
      final settings = _Settings();
      var selection = Completer<String?>();
      String? initialDirectory;
      await _open(
        tester,
        settings,
        chooseDirectory: (initial) {
          initialDirectory = initial;
          return selection.future;
        },
      );
      await tester.tap(_browse);
      await tester.pump();
      expect(initialDirectory, '/custom/projects');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(1, 1));
      await tester.pump();
      expect(find.text('Project folder'), findsOneWidget);
      selection.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('/custom/projects'), findsOneWidget);

      selection = Completer<String?>();
      await tester.tap(_browse);
      selection.complete('/chosen/projects');
      await tester.pumpAndSettle();
      expect(find.text(path.normalize('/chosen/projects')), findsOneWidget);
      expect(settings.writes, 0);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(settings.directory, path.normalize('/chosen/projects'));
    },
  );

  testWidgets('picker failure preserves the draft and reports the error', (
    tester,
  ) async {
    final settings = _Settings();
    await _open(
      tester,
      settings,
      chooseDirectory: (_) async => throw StateError('Picker unavailable'),
    );
    await tester.tap(_browse);
    await tester.pumpAndSettle();
    expect(find.text('/custom/projects'), findsOneWidget);
    expect(find.text('Could not choose a folder. Try again.'), findsOneWidget);
    expect(settings.writes, 0);
  });

  testWidgets(
    'default mode disables browsing and custom mode requires a folder',
    (tester) async {
      final settings = _Settings()..directory = null;
      var choices = 0;
      String? selected;
      String? initialDirectory;
      await _open(
        tester,
        settings,
        chooseDirectory: (initial) async {
          choices++;
          initialDirectory = initial;
          return selected;
        },
      );
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(_mode),
          scrollDelta: const Offset(0, -120),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump();
      expect(find.text('Default'), findsOneWidget);
      await tester.tap(_browse);
      expect(choices, 0);

      await _selectMode(tester, 'Custom');
      expect(find.text('Choose folder…'), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(settings.writes, 0);
      await tester.tap(_browse);
      await tester.pumpAndSettle();
      expect(initialDirectory, '/documents/Anthem/Projects');
      expect(find.text('Choose folder…'), findsOneWidget);

      selected = '/chosen/projects';
      await tester.tap(_browse);
      await tester.pumpAndSettle();
      await _selectMode(tester, 'Default');
      await _selectMode(tester, 'Custom');
      expect(find.text(path.normalize(selected)), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(settings.directory, path.normalize(selected));
    },
  );

  testWidgets('long paths fit a smaller window without expanding the dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(
      tester,
      _Settings()
        ..directory =
            '/projects/${List.filled(30, 'long folder name').join('/')}',
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SettingsDialog)).height, lessThan(110));
  });

  test('settings can finish loading after the dialog is disposed', () async {
    final controller = SettingsDialogController(_Settings());
    final loading = controller.load();
    controller.dispose();
    await loading;
  });
}

Future<void> _open(
  WidgetTester tester,
  _Settings settings, {
  ProjectsDirectoryChooser? chooseDirectory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: const ScreenOverlay(
        child: DialogRenderer(child: SizedBox.expand()),
      ),
    ),
  );
  final controller = SettingsDialogController(
    settings,
    chooseDirectory: chooseDirectory,
  );
  ServiceRegistry.dialogController.showDialog(
    title: 'Settings',
    content: SettingsDialog(
      controller: controller,
      onClose: ServiceRegistry.dialogController.closeDialog,
    ),
    canDismiss: controller.canDismiss,
  );
  await tester.pumpAndSettle();
}

Future<void> _selectMode(WidgetTester tester, String mode) async {
  await tester.tap(_mode);
  await tester.pump();
  await tester.tap(find.text(mode).last);
  await tester.pumpAndSettle();
}
