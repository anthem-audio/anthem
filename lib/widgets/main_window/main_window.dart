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

// cspell:ignore autofocus

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_cubit.dart';
import 'package:anthem/widgets/main_window/tab_content_switcher.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/main_window/window_header.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:anthem/widgets/main_window/main_window_cubit.dart';
import 'package:provider/provider.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({Key? key}) : super(key: key);

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  bool isTestMenuOpen = false;
  MenuController menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainWindowCubit, MainWindowState>(
        builder: (context, state) {
      return BlocProvider<ScreenOverlayCubit>(
        create: (context) => ScreenOverlayCubit(),
        child: ScreenOverlay(
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (e) {
              final type = e.runtimeType.toString();

              final keyDown = type == 'RawKeyDownEvent';
              final keyUp = type == 'RawKeyUpEvent';

              final ctrl = e.logicalKey.keyLabel == "Control Left" ||
                  e.logicalKey.keyLabel == "Control Right";
              final alt = e.logicalKey.keyLabel == "Alt Left" ||
                  e.logicalKey.keyLabel == "Alt Right";
              final shift = e.logicalKey.keyLabel == "Shift Left" ||
                  e.logicalKey.keyLabel == "Shift Right";

              final keyboardModifiers =
                  Provider.of<KeyboardModifiers>(context, listen: false);

              if (ctrl && keyDown) keyboardModifiers.setCtrl(true);
              if (ctrl && keyUp) keyboardModifiers.setCtrl(false);
              if (alt && keyDown) keyboardModifiers.setAlt(true);
              if (alt && keyUp) keyboardModifiers.setAlt(false);
              if (shift && keyDown) keyboardModifiers.setShift(true);
              if (shift && keyUp) keyboardModifiers.setShift(false);
            },
            child: Container(
              color: const Color(0xFF2A3237),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  children: [
                    WindowHeader(
                      selectedTabID: state.selectedTabID,
                      tabs: state.tabs,
                      setActiveProject: (ID id) {
                        context.read<MainWindowCubit>().switchTab(id);
                      },
                      closeProject: (ID id) {
                        context.read<MainWindowCubit>().closeProject(id);
                      },
                    ),
                    Expanded(
                      child: TabContentSwitcher(
                        tabs: state.tabs,
                        selectedTabID: state.selectedTabID,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
