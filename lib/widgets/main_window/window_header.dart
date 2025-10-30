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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/controller_registry.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/main_window/window_header_engine_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

class WindowHeader extends StatefulWidget {
  final Id selectedTabId;
  final List<TabDef> tabs;

  const WindowHeader({
    super.key,
    required this.selectedTabId,
    required this.tabs,
  });

  @override
  State<WindowHeader> createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  @override
  Widget build(BuildContext context) {
    final Widget windowHandleAndControls;

    if (kIsWeb) {
      windowHandleAndControls = Container(
        decoration: BoxDecoration(
          color: AnthemTheme.panel.background,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(4)),
        ),
      );
    } else {
      windowHandleAndControls = _WindowHandleAndControls();
    }

    return SizedBox(
      height: 29,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(bottom: 1),
            child: EngineIndicator(),
          ),
          const SizedBox(width: 1),
          ...widget.tabs.map<Widget>(
            (tab) => _Tab(
              isSelected: tab.id == widget.selectedTabId,
              id: tab.id,
              title: tab.title,
            ),
          ),
          Expanded(child: windowHandleAndControls),
        ],
      ),
    );
  }
}

class _WindowHandleAndControls extends StatelessWidget {
  const _WindowHandleAndControls();

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Container(
          decoration: BoxDecoration(
            color: AnthemTheme.panel.background,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(4)),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: _WindowButtons(),
          ),
        ),
      ),
    );
  }
}

/// Renders the window buttons (minimize, maximize, close) for Windows and
/// Linux.
///
/// This is a stateful widget because it must determine whether the window is
/// maximized or not. This isn't something the rest of the window header needs
/// to care about.
class _WindowButtons extends StatefulWidget {
  const _WindowButtons();

  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> with WindowListener {
  bool isMaximized = false;

  @override
  void initState() {
    super.initState();
    _updateMaximizedState();

    windowManager.addListener(this);
  }

  @override
  void onWindowEvent(String event) {
    if (event == 'maximize' || event == 'unmaximize') {
      _updateMaximizedState();
    }
  }

  void _updateMaximizedState() async {
    final isMaximized = await windowManager.isMaximized();
    if (this.isMaximized != isMaximized) {
      setState(() {
        this.isMaximized = isMaximized;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: SizedBox()),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Button(
            width: 32,
            height: 20,
            contentPadding: const EdgeInsets.all(2),
            borderRadius: BorderRadius.circular(4),
            variant: ButtonVariant.ghost,
            hideBorder: true,
            backgroundHoverGradient: (Color(0xFF555555), Color(0xFF555555)),
            icon: Icons.minimize,
            onPress: () {
              windowManager.minimize();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Button(
            width: 32,
            height: 20,
            contentPadding: const EdgeInsets.all(2),
            borderRadius: BorderRadius.circular(4),
            variant: ButtonVariant.ghost,
            hideBorder: true,
            backgroundHoverGradient: (Color(0xFF555555), Color(0xFF555555)),
            icon: isMaximized ? Icons.restoreDown : Icons.maximize,
            onPress: () async {
              if (isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Button(
            width: 32,
            height: 20,
            contentPadding: const EdgeInsets.all(2),
            borderRadius: BorderRadius.circular(4),
            variant: ButtonVariant.ghost,
            hideBorder: true,
            backgroundHoverGradient: (Color(0xFFBA322B), Color(0xFFBA322B)),
            icon: Icons.close,
            onPress: () {
              windowManager.close();
            },
          ),
        ),
        SizedBox(width: 4),
      ],
    );
  }
}

class _Tab extends StatefulWidget {
  final bool isSelected;
  final Id id;
  final String title;

  const _Tab({required this.isSelected, required this.id, required this.title});

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool closePressed = false;

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MainWindowController>(context);

    final result = GestureDetector(
      onTap: () {
        if (!closePressed) {
          controller.switchTab(widget.id);
        }
        closePressed = false;
      },
      child: Padding(
        padding: EdgeInsets.only(right: 1, bottom: widget.isSelected ? 0 : 1),
        child: Container(
          width: 115,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AnthemTheme.panel.accent
                : AnthemTheme.panel.background,
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.isSelected ? 1 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AnthemTheme.text.main),
                  ),
                ),
                Button(
                  variant: ButtonVariant.ghost,
                  width: 22,
                  height: 22,
                  hideBorder: true,
                  icon: Icons.close,
                  onPress: () {
                    closePressed = true;
                    ControllerRegistry.instance
                        .getController<ProjectController>(widget.id)
                        ?.close();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );

    return result;
  }
}
