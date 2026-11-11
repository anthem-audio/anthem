/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:async';

import 'package:anthem/logic/commands/sequence_commands.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/controls/digit_control.dart';
import 'package:anthem/widgets/basic/digit_display.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/menu/context_menu_api.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_consumer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' show ReactionDisposer, reaction;
import 'package:provider/provider.dart';

/// Project tempo editing, including a temporary tap-to-tempo mode.
class TempoControl extends StatefulWidget {
  const TempoControl({super.key});

  @override
  State<TempoControl> createState() => _TempoControlState();
}

class _TempoControlState extends State<TempoControl>
    with SingleTickerProviderStateMixin {
  static const _tapFadeDuration = Duration(milliseconds: 450);

  ProjectModel? _project;
  ProjectController? _projectController;
  int _originalDragTempo = 0;
  TapTempoSession? _tapSession;
  Timer? _completionTimer;
  ReactionDisposer? _activeProjectDisposer;
  ScreenOverlayHandle? _menu;
  int? _tapHintId;
  final _tapFocus = FocusNode(debugLabel: 'tempo');
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final project = Provider.of<ProjectModel>(context);
    final controller = Provider.of<ProjectController>(context);
    if (identical(project, _project) &&
        identical(controller, _projectController)) {
      return;
    }

    _finishTapMode(commit: false, rebuild: false);
    _menu?.close();
    _menu = null;
    _project = project;
    _projectController = controller;
  }

  void _openMenu(TapDownDetails details) {
    if (_tapSession != null) return;
    _menu?.close();
    _menu = openContextMenu(
      details.globalPosition,
      MenuDef(
        children: [
          AnthemMenuItem(
            text: 'Tap for BPM...',
            onSelected: () {
              _menu = null;
              _beginTapMode();
            },
          ),
        ],
      ),
    );
  }

  void _beginTapMode() {
    final project = _project!;
    setState(() {
      _tapSession = TapTempoSession(project.sequence.beatsPerMinuteRaw);
    });
    _projectController!.cancelTempoTap = _cancelTapMode;
    // Remove text-input focus so the project shortcut handler receives Escape.
    _tapFocus.requestFocus();
    _pulse.value = 0;
    _pulse.repeat(reverse: true);
    _activeProjectDisposer = reaction<bool>(
      (_) {
        final store = AnthemStore.instance;
        return store.activeProjectId == project.id &&
            store.projects.containsKey(project.id);
      },
      (active) {
        if (!active) _cancelTapMode();
      },
    );
  }

  void _recordTap(PointerDownEvent event) {
    final session = _tapSession;
    if (session == null || event.buttons != kPrimaryButton) return;

    final tempo = session.addTap(event.timeStamp);
    _pulse.stop();
    _pulse.value = 1;
    _pulse.animateTo(0, duration: _tapFadeDuration, curve: Curves.easeOut);

    if (tempo != null) {
      _project!.sequence.beatsPerMinuteRaw = tempo;
      _completionTimer?.cancel();
      _completionTimer = Timer(session.completionDelay!, () {
        if (mounted && identical(_tapSession, session)) {
          _finishTapMode(commit: true);
        }
      });
    }
    setState(() {});
  }

  bool _cancelTapMode() {
    if (_tapSession == null) return false;
    _finishTapMode(commit: false);
    return true;
  }

  void _finishTapMode({required bool commit, bool rebuild = true}) {
    final session = _tapSession;
    if (session == null) return;

    _tapSession = null;
    _completionTimer?.cancel();
    _completionTimer = null;
    _activeProjectDisposer?.call();
    _activeProjectDisposer = null;
    _pulse.stop();
    _hideTapHint();
    if (_projectController?.cancelTempoTap == _cancelTapMode) {
      _projectController!.cancelTempoTap = null;
    }

    final project = _project!;
    if (commit) {
      final tempo = session.estimatedTempoRaw;
      if (tempo != null && tempo != session.originalTempoRaw) {
        project.push(
          SetTempoCommand(
            oldRawTempo: session.originalTempoRaw,
            newRawTempo: tempo,
          ),
        );
      }
    } else {
      project.sequence.beatsPerMinuteRaw = session.originalTempoRaw;
    }
    _tapFocus.unfocus();
    if (rebuild) setState(() {});
  }

  bool _onRawKey(KeyEvent event) {
    if (_tapSession != null &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      return _cancelTapMode();
    }
    return false;
  }

  void _showTapHint() {
    _hideTapHint();
    _tapHintId = HintStore.instance.addHint([
      HintSection('click', 'Tap for BPM'),
      HintSection('Esc', 'Cancel and restore the original tempo'),
    ]);
  }

  void _hideTapHint() {
    if (_tapHintId == null) return;
    HintStore.instance.removeHint(_tapHintId!);
    _tapHintId = null;
  }

  Widget _buildNormalControl() {
    final project = _project!;
    return DigitControl(
      size: DigitDisplaySize.large,
      decimalPlaces: 2,
      minCharacterCount: 6,
      hint: 'Set the project tempo (right click to tap for BPM)',
      hintUnits: 'beats per minute',
      value: project.sequence.beatsPerMinute,
      onStart: () {
        _originalDragTempo = project.sequence.beatsPerMinuteRaw;
      },
      onChanged: (value) {
        project.sequence.beatsPerMinuteRaw = (value.clamp(10, 999) * 100)
            .round();
      },
      onEnd: () {
        final newTempo = project.sequence.beatsPerMinuteRaw;
        if (newTempo == _originalDragTempo) return;
        project.push(
          SetTempoCommand(
            oldRawTempo: _originalDragTempo,
            newRawTempo: newTempo,
          ),
        );
      },
    );
  }

  Widget _buildTapControl() {
    final tempo = _tapSession!.estimatedTempoRaw;
    final text = tempo == null ? 'Tap...' : (tempo / 100).toStringAsFixed(2);
    return MouseRegion(
      onEnter: (_) => _showTapHint(),
      onExit: (_) => _hideTapHint(),
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _recordTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return DigitDisplay(
              size: DigitDisplaySize.large,
              monospace: true,
              text: text.padLeft(6),
              borderColor: Color.lerp(
                AnthemTheme.control.border,
                AnthemTheme.primary.main,
                _pulse.value,
              ),
              backgroundColor: Color.lerp(
                AnthemTheme.control.background,
                Color.alphaBlend(
                  AnthemTheme.primary.subtle,
                  AnthemTheme.control.background,
                ),
                _pulse.value,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _tapFocus,
      child: ShortcutConsumer(
        key: ValueKey(_project!.id),
        id: 'tempo',
        global: true,
        rawKeyHandler: _onRawKey,
        child: TapRegion(
          groupId: _projectController!.tempoTapRegionGroupId,
          enabled: _tapSession != null,
          onTapOutside: (_) => _cancelTapMode(),
          child: GestureDetector(
            onSecondaryTapDown: _openMenu,
            child: _tapSession == null
                ? Observer(builder: (_) => _buildNormalControl())
                : _buildTapControl(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _menu?.close();
    _finishTapMode(commit: false, rebuild: false);
    _pulse.dispose();
    _tapFocus.dispose();
    super.dispose();
  }
}

/// The temporary tempo and timing history for one tap-to-tempo interaction.
///
/// Timestamps must come from a monotonic clock. This class does not mutate the
/// project or own timers; the control applies estimates and commits the edit.
class TapTempoSession {
  TapTempoSession(this.originalTempoRaw);

  final int originalTempoRaw;
  final List<Duration> _tapTimes = [];
  int? _estimatedTempoRaw;

  int? get estimatedTempoRaw => _estimatedTempoRaw;

  /// Records a tap and returns a whole-BPM estimate in hundredths of a BPM.
  ///
  /// Retains the last 16 taps (15 intervals). Duplicate or out-of-order
  /// timestamps are ignored, avoiding division by zero or a negative tempo.
  int? addTap(Duration timestamp) {
    if (_tapTimes.isNotEmpty && timestamp <= _tapTimes.last) return null;

    _tapTimes.add(timestamp);
    if (_tapTimes.length > 16) _tapTimes.removeAt(0);
    if (_tapTimes.length < 2) return null;

    final elapsed = (_tapTimes.last - _tapTimes.first).inMicroseconds;
    final tempo =
        Duration.microsecondsPerMinute * (_tapTimes.length - 1) / elapsed;
    _estimatedTempoRaw = tempo.clamp(10, 999).round() * 100;
    return estimatedTempoRaw;
  }

  /// Four beats at the latest estimate, measured from the latest tap.
  Duration? get completionDelay {
    final tempo = estimatedTempoRaw;
    if (tempo == null) return null;
    return Duration(
      microseconds: (Duration.microsecondsPerMinute * 100 * 4 / tempo).round(),
    );
  }
}
