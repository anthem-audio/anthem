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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/shortcuts/raw_key_event_singleton.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'model/project.dart';
import 'model/store.dart';
import 'widgets/main_window/main_window.dart';

GlobalKey mainWindowKey = GlobalKey();

void main() async {
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
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WindowListener {
  bool isMaximized = false;

  Future<void> _initWindow() async {
    await windowManager.setPreventClose(true);

    isMaximized = await windowManager.isMaximized();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

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

    // The below is a rough outline for save-before-exit

    // // a) Ask the user or run an auto-save
    // final shouldQuit = await _maybeSaveOrConfirm();

    // if (shouldQuit) {
    //   await windowManager.destroy();   // forces the app to exit
    // } else {
    //   // Simply return; the window stays open
    // }

    await windowManager.destroy();
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
    final contentStack = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AnthemTheme.panel.border),
        MainWindow(key: mainWindowKey),
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
