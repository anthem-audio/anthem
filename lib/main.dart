/*
  Copyright (C) 2021 - 2024 Joshua Wade

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

import 'dart:io';

import 'package:anthem/theme.dart' as anthem_theme;
import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:provider/provider.dart';

import 'model/project.dart';
import 'model/store.dart';
import 'widgets/main_window/main_window.dart';

import 'package:bitsdojo_window/bitsdojo_window.dart';

GlobalKey mainWindowKey = GlobalKey();

void main() async {
  runApp(const MyApp());

  // Make sure all engines are stopped before the application is closed
  FlutterWindowClose.setWindowShouldCloseHandler(() async {
    // Kill any running engine processes
    final store = AnthemStore.instance;

    for (final project in store.projects.values) {
      project.engine.dispose();
    }

    return true;
  });

  doWhenWindowReady(() {
    // const initialSize = Size(800, 600);
    // appWindow.minSize = initialSize;
    // appWindow.size = initialSize;
    // appWindow.alignment = Alignment.center;

    if (Platform.isWindows) {
      // This is a temporary fix for https://github.com/bitsdojo/bitsdojo_window/issues/193
      // Based on code from https://github.com/MixinNetwork/flutter-app/pull/838
      WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
        appWindow.size = appWindow.size + const Offset(0, 1);
        WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
          appWindow.size = appWindow.size + const Offset(0, -1);
        });
      });
    }
    appWindow.show();
  });

  final store = AnthemStore.instance;

  // Note: This code for creating a new project is duplicated in
  // main_window_controller.dart

  final projectModel = ProjectModel.create();

  store.projects[projectModel.id] = projectModel;
  store.projectOrder.add(projectModel.id);
  store.activeProjectID = projectModel.id;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anthem',
      color: anthem_theme.Theme.primary.main,
      builder: (context, widget) {
        return Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => GestureDetector(
              // Un-focus text boxes when clicking elsewhere
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Scaffold(
                body: MultiProvider(
                  providers: [
                    ChangeNotifierProvider(
                        create: (context) => KeyboardModifiers()),
                    Provider(create: (context) => BackgroundType.dark)
                  ],
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: anthem_theme.Theme.panel.border,
                        ),
                        MainWindow(key: mainWindowKey),
                      ],
                    ),
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
