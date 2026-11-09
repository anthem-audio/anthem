// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:anthem/engine_api/messages/messages.dart' as ipc;
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/rust_model_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Nested Rust sync fixture uses Dart model changes and the production encoder', () {
    final nested = RustSyncFixture()..isTopLevelModel = true;
    nested.setParentPropertiesOnChildren();
    Map<String, dynamic> nestedSnapshot() =>
        nested.toJson(forEngine: true, forProjectFile: false);
    const key = 'map "key"\\with\nlines';
    final nestedCase = _capture(nested, nestedSnapshot, () {
      nested.nested.add(AnthemObservableMap());
      nested.nested[0][key] = AnthemObservableList.of([FixtureSyncedChild()]);
      nested.nested[0][key]![0].value = 11;
      nested.nested[0][key]!.add(FixtureSyncedChild());
      nested.nested[0][key]![0] = FixtureSyncedChild()..value = 19;
      nested.nested[0][key]![0].value = 23;
      nested.nested[0][key]!.removeAt(1);
      nested.nested[0].remove(key);
      nested.nested = AnthemObservableList.of([
        AnthemObservableMap.of({
          'replacement': AnthemObservableList.of([FixtureSyncedChild()]),
        }),
      ]);
      nested.nested[0]['replacement']![0].value = 29;
      nested.optional = 42;
      nested.optional = null;
      nested.selection = FixtureSyncedChild();
      (nested.selection as FixtureSyncedChild).value = 31;
      nested.selection = 'union "string"\\with\nlines';
      nested.selection = 17;
      nested.selection = null;
      nested.mode = FixtureMode.sampleAndHold;
      nested.text = 'field "string"\\with\nlines';
      nested.uiOnly = 'must not reach the engine';
    }, compareEachStep: true);

    final value = {'nested': nestedCase};
    final file = File('engine-rust/tests/fixtures/model_updates.json');
    if (Platform.environment['ANTHEM_UPDATE_RUST_FIXTURES'] == '1') {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(value)}\n',
      );
    }
    expect(jsonDecode(file.readAsStringSync()), value);
    expect((nestedCase['steps'] as List).length, 19);
    expect(nestedCase['final'], isNot(contains('uiOnly')));
  });
}

Map<String, dynamic> _capture(
  AnthemModelBase root,
  Map<String, dynamic> Function() snapshot,
  void Function() mutate, {
  bool compareEachStep = false,
}) {
  final initial = snapshot();
  final steps = <Map<String, dynamic>>[];
  void changed(ModelChangeEvent change) {
    if (!change.sendToEngine) return;
    final request = ipc.ModelUpdateRequest.fromChange(
      id: steps.length + 2,
      change: change,
    );
    steps.add({
      'request': request.toJson(forEngine: true, forProjectFile: false),
      if (compareEachStep) 'expected': snapshot(),
    });
  }

  root.addRawFieldChangedListener(changed);
  try {
    mutate();
  } finally {
    root.removeRawFieldChangedListener(changed);
  }
  return {
    'initial': initial,
    'initializeRequest': ipc.ModelInitRequest(
      id: 1,
      serializedModel: jsonEncode(initial),
    ).toJson(forEngine: true, forProjectFile: false),
    'steps': steps,
    'final': snapshot(),
  };
}
