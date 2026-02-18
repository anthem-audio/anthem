/*
  Copyright (C) 2025 - 2026 Joshua Wade

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
import 'package:anthem/widgets/basic/hint/hint_display.dart';
import 'package:anthem/widgets/basic/tree_view/tree_view.dart';
import 'package:anthem/widgets/debug/widget_test_screens/button_widget_test_screen.dart';
import 'package:anthem/widgets/debug/widget_test_screens/knob_widget_test_screen.dart';
import 'package:anthem/widgets/debug/widget_test_screens/slider_widget_test_screen.dart';
import 'package:flutter/widgets.dart';

enum WidgetTestScreenId {
  button(
    key: 'widget-test-screen-button',
    title: 'Button',
    description: 'Tests for lib/widgets/basic/button.dart',
  ),
  knob(
    key: 'widget-test-screen-knob',
    title: 'Knob',
    description: 'Tests for lib/widgets/basic/controls/knob.dart',
  ),
  slider(
    key: 'widget-test-screen-slider',
    title: 'Slider',
    description: 'Tests for lib/widgets/basic/controls/slider.dart',
  );

  final String key;
  final String title;
  final String description;

  const WidgetTestScreenId({
    required this.key,
    required this.title,
    required this.description,
  });
}

class WidgetTestArea extends StatefulWidget {
  final WidgetTestScreenId initialScreen;

  const WidgetTestArea({
    super.key,
    this.initialScreen = WidgetTestScreenId.button,
  });

  @override
  State<WidgetTestArea> createState() => _WidgetTestAreaState();
}

class _WidgetTestAreaState extends State<WidgetTestArea> {
  late WidgetTestScreenId selectedScreen;

  @override
  void initState() {
    selectedScreen = widget.initialScreen;
    super.initState();
  }

  List<TreeViewItemModel> _getNavigationItems() {
    String labelForScreen(WidgetTestScreenId screen) {
      if (selectedScreen == screen) {
        return '${screen.title} (active)';
      }

      return screen.title;
    }

    return [
      TreeViewItemModel(
        key: 'widget-test-category-basic',
        label: 'Basic',
        children: [
          TreeViewItemModel(
            key: WidgetTestScreenId.button.key,
            label: labelForScreen(WidgetTestScreenId.button),
            onClick: () {
              setState(() {
                selectedScreen = WidgetTestScreenId.button;
              });
            },
          ),
          TreeViewItemModel(
            key: 'widget-test-category-basic-controls',
            label: 'Controls',
            children: [
              TreeViewItemModel(
                key: WidgetTestScreenId.knob.key,
                label: labelForScreen(WidgetTestScreenId.knob),
                onClick: () {
                  setState(() {
                    selectedScreen = WidgetTestScreenId.knob;
                  });
                },
              ),
              TreeViewItemModel(
                key: WidgetTestScreenId.slider.key,
                label: labelForScreen(WidgetTestScreenId.slider),
                onClick: () {
                  setState(() {
                    selectedScreen = WidgetTestScreenId.slider;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    ];
  }

  Widget _getScreenWidget() {
    return switch (selectedScreen) {
      WidgetTestScreenId.button => const ButtonWidgetTestScreen(),
      WidgetTestScreenId.knob => const KnobWidgetTestScreen(),
      WidgetTestScreenId.slider => const SliderWidgetTestScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF444444),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 270,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AnthemTheme.panel.backgroundDark,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AnthemTheme.panel.border),
                      ),
                      child: TreeView(items: _getNavigationItems()),
                    ),
                  ),
                ),
                Container(width: 1, color: AnthemTheme.panel.border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        Text(
                          selectedScreen.title,
                          style: TextStyle(
                            color: AnthemTheme.text.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          selectedScreen.description,
                          style: TextStyle(
                            color: AnthemTheme.text.main,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          height: 1,
                          color: AnthemTheme.panel.border.withValues(
                            alpha: 0.65,
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _getScreenWidget(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: AnthemTheme.panel.backgroundDark,
              border: Border(top: BorderSide(color: AnthemTheme.panel.border)),
            ),
            child: const HintDisplay(),
          ),
        ],
      ),
    );
  }
}

WidgetTestScreenId? tryParseWidgetTestScreenId(String value) {
  final normalized = value.trim().toLowerCase();

  for (final screen in WidgetTestScreenId.values) {
    if (screen.name == normalized) {
      return screen;
    }
  }

  return null;
}
