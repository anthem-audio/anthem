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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'dialog_controller.dart';

class _DialogState {
  Widget? currentDialogContent;
  String? currentDialogTitle;
  List<DialogButton>? currentDialogButtons;
  bool dismissible;
  final ValueListenable<bool>? canDismiss;
  final focusScope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  void Function()? onDismiss;

  _DialogState({
    required this.currentDialogContent,
    required this.currentDialogTitle,
    required this.currentDialogButtons,
    required this.dismissible,
    required this.canDismiss,
    required this.onDismiss,
  });
}

class DialogRenderer extends StatefulWidget {
  final Widget? child;

  const DialogRenderer({super.key, this.child});

  @override
  State<DialogRenderer> createState() => _DialogRendererState();
}

class _DialogRendererState extends State<DialogRenderer>
    implements DialogControllerImpl {
  List<_DialogState> dialogStack = [];

  /// Focused widget before the first dialog opened, restored when the last closes.
  FocusNode? _previousFocus;

  @override
  bool get isOpen => dialogStack.isNotEmpty;

  Widget? get currentDialogContent =>
      dialogStack.isNotEmpty ? dialogStack.last.currentDialogContent : null;
  String? get currentDialogTitle =>
      dialogStack.isNotEmpty ? dialogStack.last.currentDialogTitle : null;
  List<DialogButton>? get currentDialogButtons =>
      dialogStack.isNotEmpty ? dialogStack.last.currentDialogButtons : null;
  bool get dismissible =>
      dialogStack.isNotEmpty &&
      dialogStack.last.dismissible &&
      (dialogStack.last.canDismiss?.value ?? true);
  void Function()? get onDismiss =>
      dialogStack.isNotEmpty ? dialogStack.last.onDismiss : null;

  @override
  void initState() {
    super.initState();
    ServiceRegistry.dialogController.initialize(this);
  }

  @override
  void dispose() {
    for (final dialog in dialogStack) {
      dialog.canDismiss?.removeListener(_dismissibilityChanged);
      dialog.focusScope.dispose();
    }
    ServiceRegistry.dialogController.dispose();
    super.dispose();
  }

  @override
  void showDialog(
    Widget content, {
    String? title,
    List<DialogButton>? buttons,
    bool dismissible = true,
    ValueListenable<bool>? canDismiss,
    void Function()? onDismiss,
  }) {
    if (dialogStack.isEmpty) {
      final focus = FocusManager.instance.primaryFocus;
      if (focus?.context != null) _previousFocus = focus;
    }
    setState(() {
      dialogStack.add(
        _DialogState(
          currentDialogContent: content,
          currentDialogTitle: title,
          currentDialogButtons: buttons,
          dismissible: dismissible,
          canDismiss: canDismiss,
          onDismiss: onDismiss,
        ),
      );
    });
    canDismiss?.addListener(_dismissibilityChanged);
    final dialog = dialogStack.last;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(dialogStack.lastOrNull, dialog)) return;
      dialog.focusScope.requestFocus();
    });
  }

  @override
  void closeDialog() {
    setState(() {
      if (dialogStack.isNotEmpty) {
        final dialog = dialogStack.removeLast();
        dialog.canDismiss?.removeListener(_dismissibilityChanged);
        dialog.focusScope.dispose();
      }
    });
    final next = dialogStack.lastOrNull;
    final restoreFocus = next?.focusScope ?? _previousFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A close callback may immediately open another dialog (for example,
      // render progress). Do not move focus behind that new modal.
      if (!mounted || !identical(dialogStack.lastOrNull, next)) return;
      if (restoreFocus?.context != null) restoreFocus!.requestFocus();
    });
  }

  void _dismissibilityChanged() => setState(() {});

  void _dismiss() {
    if (!dismissible) return;
    final callback = onDismiss;
    closeDialog();
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget? blocker;
    Widget? dialog;

    if (currentDialogContent != null) {
      blocker = Positioned.fill(
        child: MouseRegion(
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(color: const Color(0x33000000)),
          ),
        ),
      );
      dialog = Positioned.fill(
        child: Center(
          child: FocusScope(
            key: ValueKey(dialogStack.last),
            node: dialogStack.last.focusScope,
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                if (event is KeyDownEvent) _dismiss();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              decoration: BoxDecoration(
                color: AnthemTheme.overlay.background,
                border: Border.all(color: AnthemTheme.overlay.border),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.25),
                    blurRadius: 14,
                  ),
                ],
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
                                    // Makes space for the close button.
                                    padding: EdgeInsets.only(
                                      right: dismissible ? 36 : 0,
                                    ),
                                    child: Text(
                                      currentDialogTitle!,
                                      style: TextStyle(
                                        color: AnthemTheme.text.main,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        currentDialogContent!,
                        if (currentDialogButtons?.isNotEmpty ?? false)
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
                    if (dismissible)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Button(
                          width: 24,
                          height: 24,
                          variant: ButtonVariant.label,
                          hideBorder: true,
                          icon: Icons.close,
                          onPress: _dismiss,
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
                                        if (button.shouldCloseDialog) {
                                          closeDialog();
                                        }
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
        ),
      );
    }

    return Provider.value(
      value: ServiceRegistry.dialogController,
      child: Stack(children: [?widget.child, ?blocker, ?dialog]),
    );
  }
}
