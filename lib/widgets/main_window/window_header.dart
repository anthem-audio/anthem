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

import 'dart:convert';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/license_text.dart';
import 'package:anthem/logic/controller_registry.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/debug/widget_test_area.dart';
import 'package:anthem/widgets/main_window/window_header_engine_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
        color: AnthemTheme.panel.backgroundLight,
      );
    } else {
      windowHandleAndControls = _WindowHandleAndControls();
    }

    return SizedBox(
      height: 41,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Row(children: [const EngineIndicator(), _ApplicationMenu()]),
          ),
          const SizedBox(width: 1),
          ...widget.tabs.map<Widget>(
            (tab) => Observer(
              builder: (context) {
                return _Tab(
                  isSelected: tab.id == widget.selectedTabId,
                  id: tab.id,
                  title: tab.title,
                  hasUnsavedChanges:
                      AnthemStore.instance.projects[tab.id]?.isDirty ?? false,
                );
              },
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
          color: AnthemTheme.panel.backgroundLight,
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
            backgroundHover: Color(0xFF555555),
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
            backgroundHover: Color(0xFF555555),
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
            backgroundHover: Color(0xFFBA322B),
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
  final bool hasUnsavedChanges;
  final Id id;
  final String title;

  const _Tab({
    required this.isSelected,
    required this.id,
    required this.title,
    required this.hasUnsavedChanges,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool closePressed = false;
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MainWindowController>(context);

    final result = MouseRegion(
      cursor: widget.isSelected ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: () {
          if (!closePressed) {
            controller.switchTab(widget.id);
          }
          closePressed = false;
        },
        child: Padding(
          // For no border between selected tab and project header, use this
          // instead:
          //
          // padding: EdgeInsets.only(right: 1, bottom: widget.isSelected ? 0 : 1),
          padding: EdgeInsets.only(right: 1, bottom: 1),
          child: Container(
            width: 108,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AnthemTheme.panel.accent
                  : AnthemTheme.panel.backgroundLight,
              border: widget.isSelected
                  ? Border(
                      top: BorderSide(
                        color: AnthemTheme.primary.main,
                        width: 2,
                      ),
                      bottom: BorderSide(
                        color: const Color(0x00000000),
                        width: 2,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.isSelected ? 1 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 10),
                  if (widget.hasUnsavedChanges)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AnthemTheme.text.main,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (widget.hasUnsavedChanges) const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AnthemTheme.text.main,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: widget.isSelected || isHovered,
                    child: Button(
                      variant: ButtonVariant.ghost,
                      backgroundHover: const Color(0x00000000),
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
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return result;
  }
}

class _ApplicationMenu extends StatefulObserverWidget {
  const _ApplicationMenu();

  @override
  State<_ApplicationMenu> createState() => _ApplicationMenuState();
}

class _ApplicationMenuState extends State<_ApplicationMenu> {
  AnthemMenuController? _fileMenuController;
  AnthemMenuController? _editMenuController;
  AnthemMenuController? _helpMenuController;

  @override
  Widget build(BuildContext context) {
    final fileMenuController = _fileMenuController ?? AnthemMenuController();
    final editMenuController = _editMenuController ?? AnthemMenuController();
    final helpMenuController = _helpMenuController ?? AnthemMenuController();

    final mainWindowController = context.read<MainWindowController>();

    final activeProjectId = AnthemStore.instance.activeProjectId;
    final activeProject = AnthemStore.instance.projects[activeProjectId]!;

    final dialogController = Provider.of<DialogController>(
      context,
      listen: false,
    );

    ProjectController getProjectController() {
      return ControllerRegistry.instance.getController<ProjectController>(
        activeProjectId,
      )!;
    }

    final fileMenuDef = MenuDef(
      children: [
        AnthemMenuItem(
          text: 'New project',
          hint: 'Create a new project',
          onSelected: () async {
            final projectId = await mainWindowController.newProject();
            mainWindowController.switchTab(projectId);
          },
        ),
        AnthemMenuItem(
          text: 'Load project...',
          hint: 'Load a project',
          onSelected: () {
            mainWindowController.loadProject().then((projectId) {
              if (projectId != null) {
                mainWindowController.switchTab(projectId);
              }
            });
          },
        ),
        Separator(),
        if (!kIsWeb)
          AnthemMenuItem(
            text: 'Save',
            hint: 'Save the active project',
            onSelected: () {
              mainWindowController.saveProject(
                activeProject.id,
                false,
                dialogController: dialogController,
              );
            },
          ),
        AnthemMenuItem(
          text: kIsWeb ? 'Download project...' : 'Save as...',
          hint: 'Save the active project to a new location',
          onSelected: () {
            mainWindowController.saveProject(
              activeProject.id,
              true,
              dialogController: dialogController,
            );
          },
        ),
        if (kDebugMode) Separator(),
        if (kDebugMode)
          AnthemMenuItem(
            text: 'Debug',
            submenu: MenuDef(
              children: [
                AnthemMenuItem(
                  text: 'Print project JSON (UI)',
                  hint: 'Print the project JSON as reported by the UI',
                  onSelected: () async {
                    // ignore: avoid_print
                    print(
                      jsonEncode(
                        AnthemStore
                            .instance
                            .projects[AnthemStore.instance.activeProjectId]!
                            .toJson(),
                      ),
                    );
                  },
                ),
                AnthemMenuItem(
                  text: 'Print project JSON (engine)',
                  hint: 'Print the project JSON as reported by the engine',
                  onSelected: () async {
                    // ignore: avoid_print
                    print(
                      await AnthemStore
                          .instance
                          .projects[AnthemStore.instance.activeProjectId]!
                          .engine
                          .modelSyncApi
                          .debugGetEngineJson(),
                    );
                  },
                ),
                Separator(),
                AnthemMenuItem(
                  text: 'Open widget test area',
                  onSelected: () {
                    final projectViewModel = getProjectController().viewModel;

                    projectViewModel.topPanelOverlayContentBuilder =
                        (context) => const WidgetTestArea();
                  },
                ),
              ],
            ),
          ),
      ],
    );
    final editMenuDef = MenuDef(
      children: [
        AnthemMenuItem(
          text: 'Undo',
          onSelected: () {
            getProjectController().undo();
          },
          hint: 'Undo (Ctrl+Z)',
        ),
        AnthemMenuItem(
          text: 'Redo',
          onSelected: () {
            getProjectController().redo();
          },
          hint: 'Redo (Ctrl+Shift+Z)',
        ),
      ],
    );
    final helpMenuDef = MenuDef(
      children: [
        AnthemMenuItem(
          text: 'About...',
          onSelected: () {
            final dialogController = Provider.of<DialogController>(
              context,
              listen: false,
            );
            dialogController.showTextDialog(
              text: [
                'Version: Pre-alpha\n\n',
                'Code copyright (C) 2021 - 2025 Joshua Wade\n',
                'UI design and icons copyright (C) 2021 - 2025 Budislav Stepanov',
              ].join(''),
              title: 'About Anthem',
              buttons: [
                DialogButton(
                  text: 'Source code',
                  shouldCloseDialog: false,
                  onPress: () {
                    launchUrl(
                      Uri.parse('https://github.com/anthem-audio/anthem'),
                    );
                  },
                ),
                DialogButton(
                  text: 'License',
                  shouldCloseDialog: false,
                  onPress: () {
                    dialogController.showTextDialog(
                      title: 'License',
                      text: agpl,
                      buttons: [DialogButton.ok()],
                    );
                  },
                ),
                DialogButton(
                  text: 'Additional license info',
                  shouldCloseDialog: false,
                  onPress: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Anthem',
                      applicationVersion: 'Pre-alpha',
                    );
                  },
                ),
                DialogButton.ok(),
              ],
            );
          },
        ),
      ],
    );

    return Container(
      color: AnthemTheme.panel.backgroundLight,
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Container(
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: AnthemTheme.panel.border, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Menu(
                menuController: fileMenuController,
                menuDef: fileMenuDef,
                offset: const Offset(0, 1),
                child: _ApplicationMenuButton(
                  text: 'File',
                  isFirst: true,
                  onPress: () {
                    fileMenuController.open();
                  },
                ),
              ),
              Menu(
                menuController: editMenuController,
                menuDef: editMenuDef,
                offset: const Offset(0, 1),
                child: Container(width: 1, color: AnthemTheme.panel.border),
              ),
              _ApplicationMenuButton(
                text: 'Edit',
                onPress: () {
                  editMenuController.open();
                },
              ),
              Menu(
                menuController: helpMenuController,
                menuDef: helpMenuDef,
                offset: const Offset(0, 1),
                child: Container(width: 1, color: AnthemTheme.panel.border),
              ),
              _ApplicationMenuButton(
                text: 'Help',
                isLast: true,
                onPress: () {
                  helpMenuController.open();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationMenuButton extends StatelessWidget {
  final String text;
  final bool isFirst;
  final bool isLast;
  final void Function()? onPress;

  const _ApplicationMenuButton({
    required this.text,
    this.isFirst = false,
    this.isLast = false,
    this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      text: text,
      hideBorder: true,
      borderRadius: BorderRadius.only(
        topLeft: isFirst ? Radius.circular(4) : Radius.zero,
        bottomLeft: isFirst ? Radius.circular(4) : Radius.zero,
        topRight: isLast ? Radius.circular(4) : Radius.zero,
        bottomRight: isLast ? Radius.circular(4) : Radius.zero,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      onPress: onPress,
    );
  }
}
