// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../fixtures/rust_model_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dart round-trips enum map keys in the compatibility model', () {
    final fixture = RustModelFixture();
    final json = fixture.toJson();
    final restored = RustModelFixture.fromJson(json);
    expect(restored.enumMap, fixture.enumMap);
    expect(restored.nullableEnumMap, fixture.nullableEnumMap);
    expect(restored.toJson(), json);
  });

  test('Rust snapshot fixtures match Dart engine serialization', () {
    final fixture = RustModelFixture();
    final cases = <Map<String, dynamic>>[
      fixture.toJson(forEngine: true, forProjectFile: false),
      (fixture
            ..optionalValue = 'present'
            ..optionalList = [5]
            ..optionalMap = {'value': 8}
            ..selection = FixtureChild())
          .toJson(forEngine: true, forProjectFile: false),
      (fixture..selection = 'union string').toJson(
        forEngine: true,
        forProjectFile: false,
      ),
      (fixture
            ..selection = -9007199254740993
            ..numberValue = 2.5
            ..sharedChild = FixtureSyncedChild())
          .toJson(forEngine: true, forProjectFile: false),
    ];
    expect(cases.first, isNot(contains('optionalValue')));
    expect(cases.first, isNot(contains('uiOnly')));
    expect(cases.first['engineOnly'], 'engine state');
    _checkFixture('serialization', cases);
  });
}

void _checkFixture(String name, Object value) {
  final file = File('engine-rust/tests/fixtures/$name.json');
  if (Platform.environment['ANTHEM_UPDATE_RUST_FIXTURES'] == '1') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(value)}\n',
    );
  }
  expect(
    jsonDecode(file.readAsStringSync()),
    value,
    reason: 'Regenerate Rust fixtures with ANTHEM_UPDATE_RUST_FIXTURES=1.',
  );
}
