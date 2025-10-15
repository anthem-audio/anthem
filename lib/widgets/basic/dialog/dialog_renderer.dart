/*
  Copyright (C) 2025 Joshua Wade

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
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'dialog_controller.dart';

class DialogRenderer extends StatefulWidget {
  final Widget? child;
  final DialogController controller;

  const DialogRenderer({super.key, required this.controller, this.child});

  @override
  State<DialogRenderer> createState() => _DialogRendererState();
}

class _DialogRendererState extends State<DialogRenderer>
    implements DialogControllerImpl {
  Widget? currentDialogContent;
  String? currentDialogTitle;
  List<DialogButton>? currentDialogButtons;
  void Function()? onDismiss;

  @override
  void initState() {
    super.initState();
    widget.controller.initialize(this);
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void showDialog(
    Widget content, {
    String? title,
    List<DialogButton>? buttons,
    void Function()? onDismiss,
  }) {
    setState(() {
      currentDialogContent = content;
      currentDialogTitle = title;
      currentDialogButtons = buttons;
      this.onDismiss = onDismiss;
    });
  }

  @override
  void closeDialog() {
    setState(() {
      currentDialogContent = null;
      currentDialogTitle = null;
      currentDialogButtons = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget? blocker;
    Widget? dialog;

    if (currentDialogContent != null) {
      blocker = Positioned.fill(
        child: GestureDetector(
          onTap: () {
            closeDialog();
            onDismiss?.call();
          },
          child: Container(color: const Color(0x88000000)),
        ),
      );
      dialog = Positioned.fill(
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: AnthemTheme.overlay.background,
              border: Border.all(color: AnthemTheme.overlay.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (currentDialogTitle != null)
                            SizedBox(
                              height: 24,
                              child: Center(
                                child: Padding(
                                  // Makes space for the close button
                                  padding: const EdgeInsets.only(right: 36),
                                  child: Text(
                                    currentDialogTitle!,
                                    style: TextStyle(
                                      color: AnthemTheme.text.main,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      currentDialogContent!,
                      const SizedBox(height: 36),
                    ],
                  ),

                  // Top divider
                  if (currentDialogTitle != null)
                    Positioned(
                      top: 28,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: AnthemTheme.overlay.border,
                      ),
                    ),

                  // Close button
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Button(
                      width: 24,
                      height: 24,
                      variant: ButtonVariant.label,
                      hideBorder: true,
                      icon: Icons.close,
                      onPress: () {
                        closeDialog();
                        onDismiss?.call();
                      },
                    ),
                  ),

                  // Action buttons
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          currentDialogButtons
                              ?.map(
                                (button) => Padding(
                                  padding: const EdgeInsets.only(left: 9),
                                  child: Button(
                                    height: 24,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    text: button.text,
                                    onPress: () {
                                      closeDialog();
                                      button.onPress?.call();
                                    },
                                  ),
                                ),
                              )
                              .toList() ??
                          [],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Provider.value(
      value: widget.controller,
      child: Stack(children: [?widget.child, ?blocker, ?dialog]),
    );
  }
}
