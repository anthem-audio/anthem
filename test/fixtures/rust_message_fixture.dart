// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

@GenerateRustModels()
library;

import 'package:anthem_codegen/include.dart';

part 'rust_message_fixture.g.dart';

@AnthemModel(serializable: true)
sealed class FixtureMessage extends _FixtureMessage
    with _$FixtureMessageAnthemModelMixin {
  FixtureMessage();

  factory FixtureMessage.fromJson(Map<String, dynamic> json) =>
      _$FixtureMessageAnthemModelMixin.fromJson(json);
}

abstract class _FixtureMessage {
  late int version;
}

@AnthemModel(serializable: true)
sealed class FixtureRequest extends _FixtureRequest
    with _$FixtureRequestAnthemModelMixin {
  FixtureRequest();

  factory FixtureRequest.fromJson(Map<String, dynamic> json) =>
      _$FixtureRequestAnthemModelMixin.fromJson(json);
}

abstract class _FixtureRequest extends FixtureMessage {
  late int id;

  @Union([String, int])
  Object routing = 'default';
}

class FixtureParent extends FixtureRequest {
  late String parentValue;

  FixtureParent.uninitialized();
}

class FixtureChild extends FixtureParent {
  late bool childValue;

  FixtureChild.uninitialized() : super.uninitialized();
}

class FixtureEvent extends FixtureMessage {
  late List<int> values;

  FixtureEvent.uninitialized();
}
