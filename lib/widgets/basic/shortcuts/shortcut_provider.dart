/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// This class describes which modifier keys are currently pressed. It is
/// provided by [ShortcutProvider].
class KeyboardModifiers with ChangeNotifier, DiagnosticableTreeMixin {
  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;

  KeyboardModifiers();

  bool get ctrl => _ctrl;
  bool get alt => _alt;
  bool get shift => _shift;

  void setCtrl(bool value) {
    _ctrl = value;
    notifyListeners();
  }

  void setAlt(bool value) {
    _alt = value;
    notifyListeners();
  }

  void setShift(bool value) {
    _shift = value;
    notifyListeners();
  }
}

/// This widget listens for shortcuts and sends them to the active
/// [ShortcutConsumer].
///
/// Each open project renders a [ShortcutProvider] widget, and this widget
/// tracks an active consumer within that provider's scope. This consumer will
/// usually be an editor, such as the piano roll. Tracking an active UI region
/// in this way allows us to specify which editor is currently accepting
/// shortcuts like copy and paste.
///
/// This class also provides an object to descendants which tells which modifier
/// keys (control, alt, shift) are currently pressed.
class ShortcutProvider extends StatefulWidget {
  final Widget child;

  /// Determines if this [ShortcutProvider] should process keystrokes.
  final bool active;

  const ShortcutProvider({super.key, required this.child, this.active = true});

  @override
  State<ShortcutProvider> createState() => _ShortcutProviderState();
}

class _ShortcutProviderState extends State<ShortcutProvider> {
  final controller = ShortcutProviderController();

  @override
  void initState() {
    super.initState();
    ServicesBinding.instance.keyboard.addHandler(_onKey);
  }

  @override
  dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (!widget.active) return false;

    final keyDown = e is KeyDownEvent;
    final keyUp = e is KeyUpEvent;
    final keyRepeat = e is KeyRepeatEvent;

    final ctrl = e.logicalKey.keyLabel == 'Control Left' ||
        e.logicalKey.keyLabel == 'Control Right';
    final alt = e.logicalKey.keyLabel == 'Alt Left' ||
        e.logicalKey.keyLabel == 'Alt Right';
    final shift = e.logicalKey.keyLabel == 'Shift Left' ||
        e.logicalKey.keyLabel == 'Shift Right';

    final keyboardModifiers =
        Provider.of<KeyboardModifiers>(context, listen: false);

    if (ctrl && keyDown) keyboardModifiers.setCtrl(true);
    if (ctrl && keyUp) keyboardModifiers.setCtrl(false);
    if (alt && keyDown) keyboardModifiers.setAlt(true);
    if (alt && keyUp) keyboardModifiers.setAlt(false);
    if (shift && keyDown) keyboardModifiers.setShift(true);
    if (shift && keyUp) keyboardModifiers.setShift(false);

    if (keyDown || keyRepeat) controller.handleKeyDown(e);
    if (keyUp) controller.handleKeyUp(e);

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(value: controller, child: widget.child);
  }
}
