/*
  Copyright (C) 2021 Joshua Wade

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

import 'dart:ui';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/menu/menu_overlay.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'widgets/main_window/main_window.dart';
import 'widgets/main_window/main_window_cubit.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Store _store = Store.instance;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Anthem',
      color: const Color.fromARGB(255, 7, 210, 212),
      builder: (context, widget) {
        return BlocProvider<MainWindowCubit>(
          create: (_) => MainWindowCubit(),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => KeyboardModifiers())
            ],
            child: MenuOverlay(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Theme.panel.border,
                  ),
                  MainWindow(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
