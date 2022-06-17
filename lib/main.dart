/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'dart:ffi';
import 'dart:io';

import 'package:anthem/theme.dart' as anthem_theme;
import 'package:anthem/widgets/basic/background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'model/store.dart';
import 'widgets/main_window/main_window.dart';
import 'widgets/main_window/main_window_cubit.dart';
import 'package:anthem/bridge_generated.dart' as bridge;

import 'package:bitsdojo_window/bitsdojo_window.dart';

const base = 'anthem';
final path = Platform.isWindows
    ? '$base.dll'
    : Platform.isMacOS
        ? 'lib$base.dylib'
        : 'lib$base.so';
late final dylib =
    Platform.isIOS ? DynamicLibrary.process() : DynamicLibrary.open(path);
late final api = bridge.AnthemImpl(dylib);

void main() async {
  Store.instance.init();
  api.startEngine(id: 0);
  runApp(const MyApp());

  doWhenWindowReady(() {
    // const initialSize = Size(800, 600);
    // appWindow.minSize = initialSize;
    // appWindow.size = initialSize;
    // appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anthem',
      color: anthem_theme.Theme.primary.main,
      builder: (context, widget) {
        return GestureDetector(
          // Un-focus text boxes when clicking elsewhere
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            body: BlocProvider<MainWindowCubit>(
              create: (_) => MainWindowCubit(),
              child: MultiProvider(
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
                      const MainWindow(),
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
