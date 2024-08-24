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
}

@AnthemModel(serializable: true)
class WithList extends _WithList with _$WithListAnthemModelMixin {
  WithList();

  factory WithList.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$WithListAnthemModelMixin.fromJson_ANTHEM(json);
}

class _WithList {
  late List<List<int>> intList;
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
}
