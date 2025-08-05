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

import 'package:anthem/theme.dart' as anthem_theme;
import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
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

  await windowManager.ensureInitialized();
  await windowManager.setAsFrameless();
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WindowListener {
  Future<void> _initWindow() async {
    await windowManager.setPreventClose(true);
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindow();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anthem',
      color: anthem_theme.Theme.primary.main,
      theme: ThemeData(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: anthem_theme.Theme.primary.subtleBorder.withAlpha(50),
        ),
      ),
      builder: (context, widget) {
        return GestureDetector(
          // Un-focus text boxes when clicking elsewhere
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (context) => KeyboardModifiers(),
                ),
                Provider(create: (context) => BackgroundType.dark),
              ],
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: DragToResizeArea(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: anthem_theme.Theme.panel.border),
                      MainWindow(key: mainWindowKey),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
