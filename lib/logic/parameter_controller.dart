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

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/project.dart';
import 'package:mobx/mobx.dart';

/// Updates the observable UI cache from confirmed engine base values.
void applyReportedParameterValues(
  NodeModel node,
  Iterable<ProcessingGraphParameterValue> values,
) {
  final ports = {for (final port in node.controlInputPorts) port.id: port};
  runInAction(() {
    for (final value in values) {
      final port = ports[value.controlPortId];
      if (port == null || port.config.parameterConfig == null) continue;
      port.parameterValue = value.value.clamp(0.0, 1.0).toDouble();
      port.parameterDisplayText = value.displayText;
    }
  });
}

/// Coordinates base-value edits, their engine confirmations, and undo gestures.
class ParameterController {
  final ProjectModel project;
  final Map<(Id, int), _ParameterChangeSession> _activeChanges = {};
  final Map<(Id, int), int> _editIds = {};
  final Map<(Id, int), int> _confirmedEditIds = {};
  final Map<(Id, int), Future<double>> _pendingValues = {};
  int _nextEditId = 0;

  ParameterController(this.project);

  bool hasActiveChanges(Id nodeId) =>
      _activeChanges.keys.any((key) => key.$1 == nodeId);

  /// Applies confirmed base values without sending edits back to the engine.
  void applyEngineValues(
    Id nodeId,
    Iterable<ProcessingGraphParameterValue> values,
  ) {
    final node = project.processingGraph.nodes[nodeId];
    if (node == null) return;
    applyReportedParameterValues(node, values);
  }

  /// Displays a pending edit immediately, then reconciles it with the engine.
  Future<double> setValue({
    required NodeModel node,
    required NodePortModel port,
    required double value,
  }) {
    _assertReady(node: node, port: port);
    final key = (node.id, port.id);
    final editId = _nextEditId++;
    _editIds[key] = editId;
    runInAction(
      () => port.pendingParameterValue = value.clamp(0.0, 1.0).toDouble(),
    );
    final completion = _sendValue(node, port, value, key, editId);
    _pendingValues[key] = completion;
    return completion;
  }

  Future<double> _sendValue(
    NodeModel node,
    NodePortModel port,
    double value,
    (Id, int) key,
    int editId,
  ) async {
    try {
      final accepted = await project.engine.processingGraphApi
          .setParameterValue(node.id, port.id, value);
      if (!identical(project.processingGraph.nodes[node.id], node) ||
          node.initializationState != NodeInitializationState.ready) {
        throw StateError(
          'The processor changed before confirming the parameter edit.',
        );
      }
      if (editId > (_confirmedEditIds[key] ?? -1)) {
        _confirmedEditIds[key] = editId;
        applyEngineValues(node.id, [accepted]);
        node.scheduleThrottledStateUpdate();
      }
      return accepted.value;
    } finally {
      if (_editIds[key] == editId) {
        _editIds.remove(key);
        _pendingValues.remove(key);
        runInAction(() => port.pendingParameterValue = null);
      }
    }
  }

  void beginChange({required NodeModel node, required NodePortModel port}) {
    _assertReady(node: node, port: port);
    final key = (node.id, port.id);
    if (_activeChanges.containsKey(key)) {
      throw StateError('A parameter gesture is already active.');
    }
    node.touchControlInputParameter(port);
    final oldValue =
        _pendingValues[key]?.then(
          (value) => value,
          onError: (Object _, StackTrace _) => port.parameterValueOrResetTarget,
        ) ??
        Future.value(port.parameterValueOrResetTarget);
    _activeChanges[key] = _ParameterChangeSession(oldValue: oldValue);
  }

  void updateChange({
    required NodeModel node,
    required NodePortModel port,
    required double value,
  }) {
    _assertReady(node: node, port: port);
    final session = _activeChanges[(node.id, port.id)];
    if (session == null) throw StateError('No parameter gesture is active.');
    final sequence = ++session.sequence;
    session.pendingCount++;
    unawaited(
      setValue(node: node, port: port, value: value)
          .then<void>(
            (accepted) {
              if (sequence > session.acceptedSequence) {
                session.acceptedSequence = sequence;
                session.acceptedValue = accepted;
              }
              if (session.sequence == sequence) session.error = null;
            },
            onError: (Object error, StackTrace stack) {
              if (session.sequence == sequence) {
                session.error = error;
                session.stack = stack;
              }
            },
          )
          .whenComplete(() {
            session.pendingCount--;
            if (session.pendingCount == 0) session.idle?.complete();
          }),
    );
  }

  Future<void> commitChange({
    required NodeModel node,
    required NodePortModel port,
  }) async {
    final session = _activeChanges.remove((node.id, port.id));
    if (session == null) return;
    await session.waitForPending();
    final oldValue = await session.oldValue;
    final newValue = session.acceptedValue;
    if (newValue != null && oldValue != newValue) {
      await project.push(
        SetParameterValueCommand(
          nodeId: node.id,
          controlPortId: port.id,
          oldValue: oldValue,
          newValue: newValue,
        ),
      );
    }
    if (session.error != null) {
      Error.throwWithStackTrace(session.error!, session.stack!);
    }
  }

  Future<void> cancelChange({
    required NodeModel node,
    required NodePortModel port,
  }) async {
    final session = _activeChanges.remove((node.id, port.id));
    if (session == null) return;
    await setValue(node: node, port: port, value: await session.oldValue);
  }

  Future<void> resetToDefault({
    required NodeModel node,
    required NodePortModel port,
  }) async {
    _assertReady(node: node, port: port);
    node.touchControlInputParameter(port);
    final oldValue =
        await (_pendingValues[(node.id, port.id)]?.then(
              (value) => value,
              onError: (Object _, StackTrace _) =>
                  port.parameterValueOrResetTarget,
            ) ??
            Future.value(port.parameterValueOrResetTarget));
    final newValue = port.parameterResetTarget.clamp(0.0, 1.0).toDouble();
    if (oldValue == newValue) return;
    await project.execute(
      SetParameterValueCommand(
        nodeId: node.id,
        controlPortId: port.id,
        oldValue: oldValue,
        newValue: newValue,
      ),
    );
  }

  void _assertReady({required NodeModel node, required NodePortModel port}) {
    if (port.nodeId != node.id ||
        port.config.parameterConfig == null ||
        !identical(project.processingGraph.nodes[node.id], node)) {
      throw StateError(
        'The parameter does not belong to a current project node.',
      );
    }
    if (!project.engine.isRunning ||
        !node.canEditParameters ||
        !port.isAvailable) {
      throw StateError('The processor is not ready for parameter edits.');
    }
  }
}

class _ParameterChangeSession {
  final Future<double> oldValue;
  int pendingCount = 0;
  Completer<void>? idle;
  Future<void> waitForPending() =>
      pendingCount == 0 ? Future.value() : (idle ??= Completer<void>()).future;
  int sequence = 0;
  int acceptedSequence = -1;
  double? acceptedValue;
  Object? error;
  StackTrace? stack;
  _ParameterChangeSession({required this.oldValue});
}
