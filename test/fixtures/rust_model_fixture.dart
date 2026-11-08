// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

@GenerateRustModels([RustModelFixture, RustSyncFixture])
library;

import 'dart:ui';

import 'package:anthem_codegen/include.dart';

part 'rust_model_fixture.g.dart';

@AnthemEnum()
enum FixtureMode { smooth, sampleAndHold }

@AnthemModel(serializable: true)
class RustModelFixture extends _RustModelFixture
    with _$RustModelFixtureAnthemModelMixin {
  static const String quotedLabel = _RustModelFixture.quotedLabel;
  static const String escapeLabel = _RustModelFixture.escapeLabel;
  static const String controlLabel = _RustModelFixture.controlLabel;

  RustModelFixture();

  factory RustModelFixture.fromJson(Map<String, dynamic> json) =>
      _$RustModelFixtureAnthemModelMixin.fromJson(json);
}

class _RustModelFixture {
  static const String quotedLabel = 'A "quoted" label\\with\nlines';
  static const String escapeLabel = r'\back\form\u1234';
  static const String controlLabel = '\b\f\u0000\t🎵';

  int integerValue = 9223372036854775807;
  double doubleValue = -0.125;
  num numberValue = 7;
  bool boolValue = true;
  String stringValue = 'Rust ↔ Dart 🎵\n"quoted"';
  String? optionalValue;
  FixtureMode mode = FixtureMode.sampleAndHold;
  Color color = const Color.fromARGB(128, 12, 34, 56);
  List<List<int?>> nestedList = [
    [1, null, -3],
    [],
  ];
  List<int>? optionalList;
  Map<String, int>? optionalMap;
  Map<int, FixtureChild> children = {42: FixtureChild()};
  FixtureSyncedChild? sharedChild;
  Map<FixtureMode, List<String>> enumMap = {
    FixtureMode.sampleAndHold: ['one', 'two'],
  };
  Map<bool, int> boolMap = {true: 1, false: 0};
  Map<String, Map<int, int>> nestedMap = {
    'values': {-1: 2},
  };

  @Union([FixtureChild, String, int])
  Object? selection;

  @hideFromCpp
  String uiOnly = 'UI state';

  @hideFromCpp
  Map<FixtureMode?, int> nullableEnumMap = {null: 1, FixtureMode.smooth: 2};

  @hideFromSerialization
  String engineOnly = 'engine state';
}

@AnthemModel(serializable: true)
class FixtureChild extends _FixtureChild with _$FixtureChildAnthemModelMixin {
  FixtureChild();

  factory FixtureChild.fromJson(Map<String, dynamic> json) =>
      _$FixtureChildAnthemModelMixin.fromJson(json);
}

class _FixtureChild {
  int type = 3;
  String name = 'nested';
}

@AnthemModel(serializable: true, generateModelSync: true)
class FixtureSyncedChild extends _FixtureSyncedChild
    with _$FixtureSyncedChildAnthemModelMixin {
  FixtureSyncedChild();

  factory FixtureSyncedChild.fromJson(Map<String, dynamic> json) =>
      _$FixtureSyncedChildAnthemModelMixin.fromJson(json);
}

abstract class _FixtureSyncedChild with AnthemModelBase {
  int value = 7;
}

@AnthemModel(serializable: true, generateModelSync: true)
class RustSyncFixture extends _RustSyncFixture
    with _$RustSyncFixtureAnthemModelMixin {
  RustSyncFixture();

  factory RustSyncFixture.fromJson(Map<String, dynamic> json) =>
      _$RustSyncFixtureAnthemModelMixin.fromJson(json);
}

abstract class _RustSyncFixture with AnthemModelBase {
  AnthemObservableList<
    AnthemObservableMap<String, AnthemObservableList<FixtureSyncedChild>>
  >
  nested = .new();
  int? optional;
  String text = '';
  FixtureMode mode = FixtureMode.smooth;

  @Union([FixtureSyncedChild, String, int])
  Object? selection;

  @hideFromCpp
  String uiOnly = '';
}
