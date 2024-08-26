/*
  Copyright (C) 2024 Joshua Wade

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

// ignore_for_file: non_constant_identifier_names

import 'package:anthem_codegen/annotations.dart';
import 'package:flutter_test/flutter_test.dart';

part 'serialization_test.g.dart';

@AnthemModel(serializable: true)
class Empty extends _Empty with _$EmptyAnthemModelMixin {
  Empty();

  factory Empty.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$EmptyAnthemModelMixin.fromJson_ANTHEM(json);
}

class _Empty {}

@AnthemModel(serializable: true)
class WithPrimitives extends _WithPrimitives
    with _$WithPrimitivesAnthemModelMixin {
  WithPrimitives();

  factory WithPrimitives.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$WithPrimitivesAnthemModelMixin.fromJson_ANTHEM(json);
}

class _WithPrimitives {
  late int intField;
  late double doubleField;
  late String stringField;
  late bool boolField;
  num? nullableNumField;
}

@AnthemModel(serializable: true)
class WithList extends _WithList with _$WithListAnthemModelMixin {
  WithList();

  factory WithList.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$WithListAnthemModelMixin.fromJson_ANTHEM(json);
}

class _WithList {
  late List<List<int?>> intList;
}

@AnthemModel(serializable: true)
class WithMap extends _WithMap with _$WithMapAnthemModelMixin {
  WithMap();

  factory WithMap.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$WithMapAnthemModelMixin.fromJson_ANTHEM(json);
}

class _WithMap {
  late Map<String, Map<int, int>> stringIntMap;
}

@AnthemModel(serializable: true)
class NestedModel extends _NestedModel with _$NestedModelAnthemModelMixin {
  NestedModel();

  factory NestedModel.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$NestedModelAnthemModelMixin.fromJson_ANTHEM(json);
}

class _NestedModel {
  late WithPrimitives withPrimitives;
}

enum TestEnum { a, b }

@AnthemModel(serializable: true)
class WithEnum extends _WithEnum with _$WithEnumAnthemModelMixin {
  WithEnum();

  factory WithEnum.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$WithEnumAnthemModelMixin.fromJson_ANTHEM(json);
}

class _WithEnum {
  late TestEnum testEnum1;
  late TestEnum testEnum2;
}

@AnthemModel(serializable: true)
class WithNullable extends _WithNullable with _$WithNullableAnthemModelMixin {
  WithNullable();

  factory WithNullable.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$WithNullableAnthemModelMixin.fromJson_ANTHEM(json);
}

class _WithNullable {
  int? nullableInt;
  List<int>? nullableList;
  Map<String, List<int?>?>? nullableMap;
  WithPrimitives? nullableModel;
}

void main() {
  test('Empty model', () {
    final json = Empty().toJson_ANTHEM();
    expect(json.isEmpty, isTrue);
  });

  test('WithPrimitives model', () {
    final model = WithPrimitives()
      ..intField = 1
      ..doubleField = 2.0
      ..stringField = '3'
      ..boolField = true;

    final json = model.toJson_ANTHEM();
    expect(json['intField'], 1);
    expect(json['doubleField'], 2.0);
    expect(json['stringField'], '3');
    expect(json['boolField'], true);

    final deserializedModel = WithPrimitives.fromJson_ANTHEM(json);
    expect(deserializedModel.intField, 1);
    expect(deserializedModel.doubleField, 2.0);
    expect(deserializedModel.stringField, '3');
    expect(deserializedModel.boolField, true);
  });

  test('WithList model', () {
    final model = WithList()
      ..intList = [
        [1, 2, 3],
        [4, 5, 6],
      ];

    final json = model.toJson_ANTHEM();
    expect(json['intList'], [
      [1, 2, 3],
      [4, 5, 6],
    ]);

    final deserializedModel = WithList.fromJson_ANTHEM(json);
    expect(deserializedModel.intList, [
      [1, 2, 3],
      [4, 5, 6],
    ]);
  });

  test('WithMap model', () {
    final model = WithMap()
      ..stringIntMap = {
        'a': {1: 2},
        'b': {3: 4},
      };

    final json = model.toJson_ANTHEM();
    expect(json['stringIntMap'], {
      'a': {'1': 2},
      'b': {'3': 4},
    });

    final deserializedModel = WithMap.fromJson_ANTHEM(json);
    expect(deserializedModel.stringIntMap, {
      'a': {1: 2},
      'b': {3: 4},
    });
  });

  test('Nested model', () {
    final model = NestedModel()
      ..withPrimitives = WithPrimitives()
      ..withPrimitives.intField = 1
      ..withPrimitives.doubleField = 2.0
      ..withPrimitives.stringField = '3'
      ..withPrimitives.boolField = true;

    final json = model.toJson_ANTHEM();
    expect(json['withPrimitives'], {
      'intField': 1,
      'doubleField': 2.0,
      'stringField': '3',
      'boolField': true,
    });

    final deserializedModel = NestedModel.fromJson_ANTHEM(json);
    expect(deserializedModel.withPrimitives.intField, 1);
  });

  test('WithEnum model', () {
    final model = WithEnum()
      ..testEnum1 = TestEnum.a
      ..testEnum2 = TestEnum.b;

    final json = model.toJson_ANTHEM();
    expect(json['testEnum1'], 'a');
    expect(json['testEnum2'], 'b');

    final deserializedModel = WithEnum.fromJson_ANTHEM(json);
    expect(deserializedModel.testEnum1, TestEnum.a);
    expect(deserializedModel.testEnum2, TestEnum.b);
  });

  test('Nullable types', () {
    final model = WithNullable()
      ..nullableInt = 1
      ..nullableList = [1, 2, 3]
      ..nullableMap = {
        'a': [1, 2, 3],
        'b': [4, 5, null],
        'c': null,
      }
      ..nullableModel = (WithPrimitives()
        ..intField = 1
        ..doubleField = 2.0
        ..stringField = '3'
        ..boolField = true);

    final json = model.toJson_ANTHEM();
    expect(json['nullableInt'], 1);
    expect(json['nullableList'], [1, 2, 3]);
    expect(json['nullableMap'], {
      'a': [1, 2, 3],
      'b': [4, 5, null],
      'c': null,
    });
    expect(json['nullableModel'], {
      'intField': 1,
      'doubleField': 2.0,
      'stringField': '3',
      'boolField': true,
    });

    final deserializedModel = WithNullable.fromJson_ANTHEM(json);
    expect(deserializedModel.nullableInt, 1);
    expect(deserializedModel.nullableMap, {
      'a': [1, 2, 3],
      'b': [4, 5, null],
      'c': null,
    });
    expect(deserializedModel.nullableModel?.intField, 1);
    expect(deserializedModel.nullableModel?.doubleField, 2.0);
    expect(deserializedModel.nullableModel?.stringField, '3');
    expect(deserializedModel.nullableModel?.boolField, true);

    // Same as above, but with null values

    final emptyModel = WithNullable();
    final emptyJson = emptyModel.toJson_ANTHEM();

    expect(emptyJson['nullableInt'], null);
    expect(emptyJson['nullableList'], null);
    expect(emptyJson['nullableMap'], null);
    expect(emptyJson['nullableModel'], null);

    final emptyDeserializedModel = WithNullable.fromJson_ANTHEM(emptyJson);
    expect(emptyDeserializedModel.nullableInt, null);
    expect(emptyDeserializedModel.nullableList, null);
    expect(emptyDeserializedModel.nullableMap, null);
    expect(emptyDeserializedModel.nullableModel, null);
  });
}
