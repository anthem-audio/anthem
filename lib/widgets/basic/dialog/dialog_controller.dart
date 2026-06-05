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
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

abstract class DialogControllerImpl {
  void showDialog(
    Widget content, {
    String? title,
    List<DialogButton>? buttons,
    void Function()? onDismiss,
  });
  void closeDialog();
}

class DialogController {
  DialogControllerImpl? _impl;

  static const _textDialogMaxWidth = 450.0;
  static const _textDialogMaxHeight = 250.0;

  void initialize(DialogControllerImpl impl) {
    _impl = impl;
  }

  void dispose() {
    _impl = null;
  }

  void showDialog({
    String? title,
    required Widget content,
    List<DialogButton>? buttons,
    void Function()? onDismiss,
  }) {
    _impl?.showDialog(
      content,
      title: title,
      buttons: buttons,
      onDismiss: onDismiss,
    );
  }

  void showMarkdownDialog({
    String? title,
    required String markdown,
    List<DialogButton>? buttons,
    void Function()? onDismiss,
    MarkdownTapLinkCallback? onTapLink,
  }) {
    _impl?.showDialog(
      _MarkdownDialogContent(
        markdown: markdown,
        onTapLink: onTapLink,
        maxWidth: _textDialogMaxWidth,
        maxHeight: _textDialogMaxHeight,
      ),
      title: title,
      buttons: buttons,
      onDismiss: onDismiss,
    );
  }

  void closeDialog() {
    _impl?.closeDialog();
  }
}

class _MarkdownDialogContent extends StatefulWidget {
  final String markdown;
  final MarkdownTapLinkCallback? onTapLink;
  final double maxWidth;
  final double maxHeight;

  const _MarkdownDialogContent({
    required this.markdown,
    required this.onTapLink,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  State<_MarkdownDialogContent> createState() => _MarkdownDialogContentState();
}

class _MarkdownDialogContentState extends State<_MarkdownDialogContent> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: MarkdownBody(
            data: widget.markdown,
            onTapLink: widget.onTapLink,
            styleSheet: _dialogMarkdownStyleSheet(),
            softLineBreak: true,
          ),
        ),
      ),
    );
  }
}

String escapeDialogMarkdown(String text) {
  final buffer = StringBuffer();
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  for (final rune in normalized.runes) {
    final character = String.fromCharCode(rune);
    if (r'\`*_{}[]()#+-.!|<>'.contains(character)) {
      buffer.write(r'\');
    }
    buffer.write(character);
  }

  return buffer.toString();
}

MarkdownStyleSheet _dialogMarkdownStyleSheet() {
  final bodyStyle = TextStyle(
    color: AnthemTheme.text.main,
    fontSize: 13,
    height: 1.25,
  );

  return MarkdownStyleSheet(
    a: bodyStyle.copyWith(
      color: AnthemTheme.primary.main,
      decoration: TextDecoration.underline,
      decorationColor: AnthemTheme.primary.main,
    ),
    p: bodyStyle,
    pPadding: EdgeInsets.zero,
    code: bodyStyle.copyWith(
      backgroundColor: AnthemTheme.panel.backgroundDark,
      fontFamily: 'RobotoMono',
      fontSize: 12,
    ),
    h1: bodyStyle.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
    h1Padding: const EdgeInsets.only(bottom: 2),
    h2: bodyStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    h2Padding: const EdgeInsets.only(bottom: 2),
    h3: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    h3Padding: const EdgeInsets.only(bottom: 2),
    h4: bodyStyle.copyWith(fontWeight: FontWeight.w600),
    h4Padding: EdgeInsets.zero,
    h5: bodyStyle.copyWith(fontWeight: FontWeight.w600),
    h5Padding: EdgeInsets.zero,
    h6: bodyStyle.copyWith(fontWeight: FontWeight.w600),
    h6Padding: EdgeInsets.zero,
    em: const TextStyle(fontStyle: FontStyle.italic),
    strong: const TextStyle(fontWeight: FontWeight.bold),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    blockquote: bodyStyle.copyWith(color: AnthemTheme.text.accent),
    blockSpacing: 6,
    listIndent: 18,
    listBullet: bodyStyle,
    listBulletPadding: const EdgeInsets.only(right: 4),
    blockquotePadding: const EdgeInsets.only(left: 8),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: AnthemTheme.overlay.border)),
    ),
    codeblockPadding: const EdgeInsets.all(8),
    codeblockDecoration: BoxDecoration(
      color: AnthemTheme.panel.backgroundDark,
      border: Border.all(color: AnthemTheme.panel.border),
      borderRadius: BorderRadius.circular(3),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: AnthemTheme.overlay.border)),
    ),
  );
}

class DialogButton {
  final String text;
  final void Function()? onPress;
  final bool isDismissive;
  final bool shouldCloseDialog;

  DialogButton({
    required this.text,
    this.onPress,
    this.isDismissive = false,
    this.shouldCloseDialog = true,
  });

  DialogButton.ok({this.onPress})
    : text = 'OK',
      isDismissive = false,
      shouldCloseDialog = true;
  DialogButton.cancel({this.onPress})
    : text = 'Cancel',
      isDismissive = true,
      shouldCloseDialog = true;
}
