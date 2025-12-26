/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'package:anthem/licenses.dart';
import 'package:anthem/logic/controller_registry.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/shortcuts/raw_key_event_singleton.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem_codegen/include/model_base_mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'model/project.dart';
import 'model/store.dart';
import 'widgets/main_window/main_window.dart';
import 'web_init_stub.dart' if (dart.library.js_interop) 'web_init.dart';

GlobalKey mainWindowKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pointerLock.ensureInitialized();

  addLicenses();

  final store = AnthemStore.instance;

  // Note: This code for creating a new project is duplicated in
  // main_window_controller.dart

  final projectModel = ProjectModel.create();

  store.projects[projectModel.id] = projectModel;
  store.projectOrder.add(projectModel.id);
  store.activeProjectId = projectModel.id;

  runApp(const App());

  if (!kIsWeb) {
    await windowManager.ensureInitialized();
    await windowManager.setAsFrameless();
  }

  // Only defined on web
  webInit();
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WindowListener {
  bool isMaximized = false;
  DialogController dialogController = DialogController();

  Future<void> _initWindow() async {
    await windowManager.setPreventClose(true);

    isMaximized = await windowManager.isMaximized();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    ControllerRegistry.instance.dialogController = dialogController;

    if (!kIsWeb) {
      windowManager.addListener(this);
      _initWindow();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      windowManager.removeListener(this);
    }

    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Kill any running engine processes
    final store = AnthemStore.instance;

    for (final project in store.projects.values) {
      try {
        await project.engine.dispose();
      } catch (e) {
        // Doesn't matter if it fails, the engine process will shut itself down
        // if needed - also, the engine process is parented to this one, so it
        // should exit no matter what.
      }
    }

    final shouldQuit = await _maybeSaveOrConfirm();

    if (shouldQuit) {
      await windowManager.destroy();
    }
  }

  Future<bool> _maybeSaveOrConfirm() async {
    // Check for dirty projects
    final projects = AnthemStore.instance.projects.values;

    for (final project in [...projects].reversed) {
      if (!project.isDirty) {
        ControllerRegistry.instance.mainWindowController!
            .closeProjectWithoutSaving(project.id);
        continue;
      }

      ControllerRegistry.instance.mainWindowController!.switchTab(project.id);

      final projectController = ControllerRegistry.instance
          .getController<ProjectController>(project.id);
      final didClose = await projectController?.close();

      if (didClose != true) {
        return false;
      }
    }

    return true;
  }

  @override
  onWindowBlur() {
    // This will send key-up events for modifier keys (alt, ctrl, shift) when
    // the window loses focus, so they don't remain stuck in the pressed state.
    RawKeyEventSingleton.instance.onBlur();
  }

  @override
  onWindowMaximize() {
    setState(() {
      isMaximized = true;
    });
  }

  @override
  onWindowUnmaximize() {
    setState(() {
      isMaximized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(
      blockObservationBuilderDepth == 0,
      'blockObservationBuilderDepth is not zero at the start of App.build(). This indicates a mismatch in begin/end observation block calls somewhere in the app.',
    );

    final contentStack = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF2F2F2F)),
        MainWindow(key: mainWindowKey, dialogController: dialogController),

        // Uncomment for performance overlay

        // Positioned(
        //   right: 0,
        //   bottom: 0,
        //   child: SizedBox(
        //     width: 300,
        //     height: 200,
        //     child: PerformanceOverlay.allEnabled(),
        //   ),
        // ),
      ],
    );

    final windowResizeAreaWithContent = kIsWeb
        ? contentStack
        : DragToResizeArea(
            enableResizeEdges: isMaximized ? [] : null,
            child: contentStack,
          );

    return MaterialApp(
      title: 'Anthem',
      color: AnthemTheme.primary.main,
      theme: ThemeData(
        fontFamily: 'Roboto',
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: AnthemTheme.primary.subtleBorder.withAlpha(50),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AnthemTheme.primary.main,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => KeyboardModifiers()),
          ],
          child: windowResizeAreaWithContent,
        ),
      ),
      builder: (context, child) {
        return GestureDetector(
          // Un-focus text boxes when clicking elsewhere
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: child!,
          ),
        );
      },
    );
  }
}
