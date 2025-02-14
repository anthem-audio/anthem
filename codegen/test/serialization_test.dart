/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

import 'package:anthem_codegen/include/annotations.dart';
import 'package:flutter_test/flutter_test.dart';

part 'serialization_test.g.dart';

@AnthemModel(serializable: true)
class Empty extends _Empty with _$EmptyAnthemModelMixin {
  Empty();

  factory Empty.fromJson(Map<String, dynamic> json) =>
      _$EmptyAnthemModelMixin.fromJson(json);
}

class _Empty {}

@AnthemModel(serializable: true)
class WithPrimitives extends _WithPrimitives
    with _$WithPrimitivesAnthemModelMixin {
  WithPrimitives();

  factory WithPrimitives.fromJson(Map<String, dynamic> json) =>
      _$WithPrimitivesAnthemModelMixin.fromJson(json);
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

  factory WithList.fromJson(Map<String, dynamic> json) =>
      _$WithListAnthemModelMixin.fromJson(json);
}

class _WithList {
  late List<List<int?>> intList;
}

@AnthemModel(serializable: true)
class WithMap extends _WithMap with _$WithMapAnthemModelMixin {
  WithMap();

  factory WithMap.fromJson(Map<String, dynamic> json) =>
      _$WithMapAnthemModelMixin.fromJson(json);
}

class _WithMap {
  late Map<String, Map<int, int>> stringIntMap;
}

@AnthemModel(serializable: true)
class NestedModel extends _NestedModel with _$NestedModelAnthemModelMixin {
  NestedModel();

  factory NestedModel.fromJson(Map<String, dynamic> json) =>
      _$NestedModelAnthemModelMixin.fromJson(json);
}

class _NestedModel {
  late WithPrimitives withPrimitives;
}

enum TestEnum { a, b }

@AnthemModel(serializable: true)
class WithEnum extends _WithEnum with _$WithEnumAnthemModelMixin {
  WithEnum();

  factory WithEnum.fromJson(Map<String, dynamic> json) =>
      _$WithEnumAnthemModelMixin.fromJson(json);
}

class _WithEnum {
  late TestEnum testEnum1;
  late TestEnum testEnum2;
}

@AnthemModel(serializable: true)
class WithNullable extends _WithNullable with _$WithNullableAnthemModelMixin {
  WithNullable();

  factory WithNullable.fromJson(Map<String, dynamic> json) =>
      _$WithNullableAnthemModelMixin.fromJson(json);
}

class _WithNullable {
  int? nullableInt;
  List<int>? nullableList;
  Map<String, List<int?>?>? nullableMap;
  WithPrimitives? nullableModel;
}

@AnthemModel(serializable: true)
class WithUnion extends _WithUnion with _$WithUnionAnthemModelMixin {
  WithUnion();

  factory WithUnion.fromJson(Map<String, dynamic> json) =>
      _$WithUnionAnthemModelMixin.fromJson(json);
}

class _WithUnion {
  @Union([UnionSubTypeOne, UnionSubTypeTwo, UnionSubTypeThree, String])
  late Object unionField;

  @Union([String, int])
  late Object? unionFieldNullable;
}

@AnthemModel(serializable: true)
class UnionSubTypeOne extends _UnionSubTypeOne
    with _$UnionSubTypeOneAnthemModelMixin {
  UnionSubTypeOne();

  factory UnionSubTypeOne.fromJson(Map<String, dynamic> json) =>
      _$UnionSubTypeOneAnthemModelMixin.fromJson(json);
}

class _UnionSubTypeOne {
  late String field;
}

@AnthemModel(serializable: true)
class UnionSubTypeTwo extends _UnionSubTypeTwo
    with _$UnionSubTypeTwoAnthemModelMixin {
  UnionSubTypeTwo();

  factory UnionSubTypeTwo.fromJson(Map<String, dynamic> json) =>
      _$UnionSubTypeTwoAnthemModelMixin.fromJson(json);
}

class _UnionSubTypeTwo {
  late int field;
}

@AnthemModel(serializable: true)
class UnionSubTypeThree extends _UnionSubTypeThree
    with _$UnionSubTypeThreeAnthemModelMixin {
  UnionSubTypeThree();

  factory UnionSubTypeThree.fromJson(Map<String, dynamic> json) =>
      _$UnionSubTypeThreeAnthemModelMixin.fromJson(json);
}

class _UnionSubTypeThree {
  late bool field;
}

void main() {
  test('Empty model', () {
    final json = Empty().toJson();
    expect(json.isEmpty, isTrue);
  });

  test('WithPrimitives model', () {
    final model =
        WithPrimitives()
          ..intField = 1
          ..doubleField = 2.0
          ..stringField = '3'
          ..boolField = true;

    final json = model.toJson();
    expect(json['intField'], 1);
    expect(json['doubleField'], 2.0);
    expect(json['stringField'], '3');
    expect(json['boolField'], true);

    final deserializedModel = WithPrimitives.fromJson(json);
    expect(deserializedModel.intField, 1);
    expect(deserializedModel.doubleField, 2.0);
    expect(deserializedModel.stringField, '3');
    expect(deserializedModel.boolField, true);
  });

  test('WithList model', () {
    final model =
        WithList()
          ..intList = [
            [1, 2, 3],
            [4, 5, 6],
          ];

    final json = model.toJson();
    expect(json['intList'], [
      [1, 2, 3],
      [4, 5, 6],
    ]);

    final deserializedModel = WithList.fromJson(json);
    expect(deserializedModel.intList, [
      [1, 2, 3],
      [4, 5, 6],
    ]);
  });

  test('WithMap model', () {
    final model =
        WithMap()
          ..stringIntMap = {
            'a': {1: 2},
            'b': {3: 4},
          };

    final json = model.toJson();
    expect(json['stringIntMap'], {
      'a': {'1': 2},
      'b': {'3': 4},
    });

    final deserializedModel = WithMap.fromJson(json);
    expect(deserializedModel.stringIntMap, {
      'a': {1: 2},
      'b': {3: 4},
    });
  });

  test('Nested model', () {
    final model =
        NestedModel()
          ..withPrimitives = WithPrimitives()
          ..withPrimitives.intField = 1
          ..withPrimitives.doubleField = 2.0
          ..withPrimitives.stringField = '3'
          ..withPrimitives.boolField = true;

    final json = model.toJson();
    expect(json['withPrimitives'], {
      'intField': 1,
      'doubleField': 2.0,
      'stringField': '3',
      'boolField': true,
    });

    final deserializedModel = NestedModel.fromJson(json);
    expect(deserializedModel.withPrimitives.intField, 1);
  });

  test('WithEnum model', () {
    final model =
        WithEnum()
          ..testEnum1 = TestEnum.a
          ..testEnum2 = TestEnum.b;

    final json = model.toJson();
    expect(json['testEnum1'], 'a');
    expect(json['testEnum2'], 'b');

    final deserializedModel = WithEnum.fromJson(json);
    expect(deserializedModel.testEnum1, TestEnum.a);
    expect(deserializedModel.testEnum2, TestEnum.b);
  });

  test('Nullable types', () {
    final model =
        WithNullable()
          ..nullableInt = 1
          ..nullableList = [1, 2, 3]
          ..nullableMap = {
            'a': [1, 2, 3],
            'b': [4, 5, null],
            'c': null,
          }
          ..nullableModel =
              (WithPrimitives()
                ..intField = 1
                ..doubleField = 2.0
                ..stringField = '3'
                ..boolField = true);

    final json = model.toJson();
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

    final deserializedModel = WithNullable.fromJson(json);
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
    final emptyJson = emptyModel.toJson();

    expect(emptyJson['nullableInt'], null);
    expect(emptyJson['nullableList'], null);
    expect(emptyJson['nullableMap'], null);
    expect(emptyJson['nullableModel'], null);

    final emptyDeserializedModel = WithNullable.fromJson(emptyJson);
    expect(emptyDeserializedModel.nullableInt, null);
    expect(emptyDeserializedModel.nullableList, null);
    expect(emptyDeserializedModel.nullableMap, null);
    expect(emptyDeserializedModel.nullableModel, null);
  });

  test('Union types', () {
    final model =
        WithUnion()
          ..unionField = (UnionSubTypeOne()..field = 'a')
          ..unionFieldNullable = 1;

    final json = model.toJson();
    expect(json['unionField'], {
      'UnionSubTypeOne': {'field': 'a'},
    });
    expect(json['unionFieldNullable'], {'int': 1});

    final deserializedModel = WithUnion.fromJson(json);
    expect((deserializedModel.unionField as UnionSubTypeOne).field, 'a');
    expect(deserializedModel.unionFieldNullable, 1);

    final model2 =
        WithUnion()
          ..unionField = 'test'
          ..unionFieldNullable = null;

    final json2 = model2.toJson();
    expect(json2['unionField'], {'String': 'test'});
    expect(json2['unionFieldNullable'], null);

    final deserializedModel2 = WithUnion.fromJson(json2);
    expect(deserializedModel2.unionField, 'test');
    expect(deserializedModel2.unionFieldNullable, null);
  });
}
