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
import 'package:anthem/widgets/debug/widget_test_screens/checkbox_widget_test_screen.dart';
import 'package:anthem/widgets/debug/widget_test_screens/dialog_widget_test_screen.dart';
import 'package:anthem/widgets/debug/widget_test_screens/knob_widget_test_screen.dart';
import 'package:anthem/widgets/debug/widget_test_screens/meter_widget_test_screen.dart';
import 'package:anthem/widgets/debug/widget_test_screens/radio_button_widget_test_screen.dart';
import 'package:anthem/widgets/debug/widget_test_screens/render_dialog_widget_test_screen.dart';
import 'package:anthem/widgets/debug/widget_test_screens/slider_widget_test_screen.dart';
import 'package:flutter/widgets.dart';

enum WidgetTestScreenId {
  button(
    key: 'widget-test-screen-button',
    title: 'Button',
    description: 'Tests for lib/widgets/basic/button.dart',
  ),
  checkbox(
    key: 'widget-test-screen-checkbox',
    title: 'Checkbox',
    description: 'Tests for lib/widgets/basic/checkbox.dart',
  ),
  radioButton(
    key: 'widget-test-screen-radio-button',
    title: 'Radio button',
    description: 'Tests for lib/widgets/basic/radio_button.dart',
  ),
  dialog(
    key: 'widget-test-screen-dialog',
    title: 'Dialog',
    description: 'Tests for lib/widgets/basic/dialog',
  ),
  meter(
    key: 'widget-test-screen-meter',
    title: 'Meter',
    description: 'Tests for lib/widgets/basic/meter.dart',
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
  ),
  renderDialog(
    key: 'widget-test-screen-render-dialog',
    title: 'Render dialog',
    description: 'Tests for lib/widgets/main_window/render_dialog.dart',
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
            key: WidgetTestScreenId.checkbox.key,
            label: labelForScreen(WidgetTestScreenId.checkbox),
            onClick: () {
              setState(() {
                selectedScreen = WidgetTestScreenId.checkbox;
              });
            },
          ),
          TreeViewItemModel(
            key: WidgetTestScreenId.radioButton.key,
            label: labelForScreen(WidgetTestScreenId.radioButton),
            onClick: () {
              setState(() {
                selectedScreen = WidgetTestScreenId.radioButton;
              });
            },
          ),
          TreeViewItemModel(
            key: WidgetTestScreenId.meter.key,
            label: labelForScreen(WidgetTestScreenId.meter),
            onClick: () {
              setState(() {
                selectedScreen = WidgetTestScreenId.meter;
              });
            },
          ),
          TreeViewItemModel(
            key: WidgetTestScreenId.dialog.key,
            label: labelForScreen(WidgetTestScreenId.dialog),
            onClick: () {
              setState(() {
                selectedScreen = WidgetTestScreenId.dialog;
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
      TreeViewItemModel(
        key: 'widget-test-category-main-window',
        label: 'Main window',
        children: [
          TreeViewItemModel(
            key: WidgetTestScreenId.renderDialog.key,
            label: labelForScreen(WidgetTestScreenId.renderDialog),
            onClick: () {
              setState(() {
                selectedScreen = WidgetTestScreenId.renderDialog;
              });
            },
          ),
        ],
      ),
    ];
  }

  Widget _getScreenWidget() {
    return switch (selectedScreen) {
      WidgetTestScreenId.button => const ButtonWidgetTestScreen(),
      WidgetTestScreenId.checkbox => const CheckboxWidgetTestScreen(),
      WidgetTestScreenId.radioButton => const RadioButtonWidgetTestScreen(),
      WidgetTestScreenId.dialog => const DialogWidgetTestScreen(),
      WidgetTestScreenId.meter => const MeterWidgetTestScreen(),
      WidgetTestScreenId.knob => const KnobWidgetTestScreen(),
      WidgetTestScreenId.slider => const SliderWidgetTestScreen(),
      WidgetTestScreenId.renderDialog => const RenderDialogWidgetTestScreen(),
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
    if (screen.name.toLowerCase() == normalized) {
      return screen;
    }
  }

  return null;
}
