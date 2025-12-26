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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/dialog/dialog_renderer.dart';
import 'package:anthem/widgets/editors/piano_roll/note_label_image_cache.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay.dart';
import 'package:anthem/widgets/main_window/tab_content_switcher.dart';
import 'package:anthem/widgets/main_window/window_header.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:web/web.dart';

class MainWindow extends StatefulWidget {
  final DialogController dialogController;

  const MainWindow({super.key, required this.dialogController});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  bool isTestMenuOpen = false;
  AnthemMenuController menuController = AnthemMenuController();
  MainWindowController controller = MainWindowController();

  bool firstBuild = true;

  @override
  void initState() {
    super.initState();
    ServiceRegistry.mainWindowController = controller;
  }

  @override
  Widget build(BuildContext context) {
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
          widget.dialogController.showTextDialog(
            title: 'Welcome',
            textSpan: TextSpan(
              style: TextStyle(color: AnthemTheme.text.main, fontSize: 13),
              children: [
                TextSpan(
                  text:
                      'This is an early preview of Anthem, a free and open-source digital audio workstation.\n\nAnthem is still ',
                ),
                TextSpan(
                  text: 'in early development',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ', and so '),
                TextSpan(
                  text: 'does not work',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' for most uses.\n\nFeel free to explore, and please ',
                ),
                TextSpan(
                  text: 'report any bugs on GitHub',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: AnthemTheme.primary.main,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      launchUrl(
                        Uri.parse('https://github.com/anthem-audio/anthem'),
                      );
                    },
                ),
                TextSpan(
                  text:
                      '. For better performance, lower latency, and third-party plugin support, try ',
                ),
                TextSpan(
                  text: 'the desktop version',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: AnthemTheme.primary.main,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      launchUrl(
                        Uri.parse('https://github.com/anthem-audio/anthem'),
                      );
                    },
                ),
                TextSpan(text: ', available for Windows, macOS, and Linux.'),
              ],
            ),
            buttons: [DialogButton.ok()],
          );
        });
      }
    }

    if (!noteLabelImageCache.initialized) {
      noteLabelImageCache.init(View.of(context).devicePixelRatio);
    }

    final store = AnthemStore.instance;

    return Provider.value(
      value: controller,
      child: DialogRenderer(
        controller: widget.dialogController,
        child: ScreenOverlay(
          child: Container(
            color: AnthemTheme.panel.border,
            child: Padding(
              padding: const EdgeInsets.all(3),
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
        ),
      ),
    );
  }
}
