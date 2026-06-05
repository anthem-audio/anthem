/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/dialog/dialog_renderer.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/widgets.dart';

import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay.dart';
import 'package:anthem/widgets/main_window/tab_content_switcher.dart';
import 'package:anthem/widgets/main_window/window_header.dart';
import 'package:url_launcher/url_launcher.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  bool isTestMenuOpen = false;
  AnthemMenuController menuController = AnthemMenuController();

  bool firstBuild = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    ServiceRegistry.mainWindowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ServiceRegistry.mainWindowViewModel;
    final store = AnthemStore.instance;

    if (firstBuild) {
      firstBuild = false;

      // On web, we show an intro dialog.
      //
      // This is because we expect that web users are less invested, and so are
      // more likely to be turned off by Anthem's current complete lack of
      // usability as a DAW, so hopefully this preempts that a bit.
      //
      // This also allows the web audio context to initialize, since it requires
      // a user gesture.
      if (kIsWeb) {
        Future(() {
          ServiceRegistry.dialogController.showMarkdownDialog(
            title: 'Welcome',
            markdown:
                'This is an early preview of Anthem, a free and open-source '
                'digital audio workstation.\n\n'
                'Anthem is still **in early development**, and so '
                '**does not work** for most uses.\n\n'
                'Feel free to explore, and please '
                '[report any bugs on GitHub](https://github.com/anthem-audio/anthem). '
                'For better performance, lower latency, and third-party plugin '
                'support, try '
                '[the desktop version](https://github.com/anthem-audio/anthem), '
                'available for Windows, macOS, and Linux.',
            onTapLink: (_, href, _) {
              if (href != null) {
                launchUrl(Uri.parse(href));
              }
            },
            buttons: [DialogButton.ok()],
          );
        });
      }
    }

    return Stack(
      fit: .expand,
      children: [
        DialogRenderer(
          child: ScreenOverlay(
            child: Observer(
              builder: (context) {
                final tabs = store.projectOrder.map<TabDef>((projectId) {
                  return TabDef(
                    id: projectId,
                    title: store.projects[projectId]?.name ?? '',
                  );
                }).toList();

                return Column(
                  children: [
                    RepaintBoundary(
                      child: WindowHeader(
                        selectedTabId: store.activeProjectId,
                        tabs: tabs,
                      ),
                    ),
                    Expanded(
                      child: TabContentSwitcher(
                        tabs: tabs,
                        selectedTabId: store.activeProjectId,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Sets an override for the mouse cursor, which should be used when
        // the mouse is pressed down during click-and-drag operations. While
        // active, this also shields underlying hover regions from layout churn
        // during resizes.
        //
        // See pushCursorOverride() and clearAllCursorOverrides() from
        // MainWindowController for examples on how to use this.
        Observer(
          builder: (context) {
            final globalCursor = viewModel.globalCursor;
            if (globalCursor == MouseCursor.defer) {
              return MouseRegion(
                cursor: globalCursor,
                hitTestBehavior: .translucent,
              );
            }

            return Positioned.fill(
              child: MouseRegion(
                key: const ValueKey('global-cursor-hover-shield'),
                cursor: globalCursor,
                opaque: true,
                hitTestBehavior: .opaque,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerUp: (_) {
                    ServiceRegistry.mainWindowController
                        .clearAllCursorOverrides();
                  },
                  onPointerCancel: (_) {
                    ServiceRegistry.mainWindowController
                        .clearAllCursorOverrides();
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
