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

import 'package:anthem_codegen/include/annotations.dart';
import 'package:flutter_test/flutter_test.dart';

part 'sealed_class_serialization_test.g.dart';

@AnthemModel(serializable: true)
sealed class SealedClass extends _SealedClass
    with _$SealedClassAnthemModelMixin {
  SealedClass();

  factory SealedClass.fromJson(Map<String, dynamic> json) =>
      _$SealedClassAnthemModelMixin.fromJson(json);
}

class _SealedClass {
  late int baseField;
}

class SealedClassA extends SealedClass {
  late int a;

  SealedClassA(this.a);
  SealedClassA.uninitialized();
}

class SealedClassB extends SealedClass {
  late int b;

  SealedClassB();
  // The uninitialized constructor is not required, so long as there is a
  // default constructor with no arguments.
}

class SealedClassC extends SealedClass {
  late int c;

  SealedClassC();
  SealedClassC.uninitialized();
}

void main() {
  test('Test sealed classes', () {
    final sealedClassA = SealedClassA(-1)
      ..baseField = 1
      ..a = 2;
    final sealedClassB = SealedClassB()
      ..baseField = 3
      ..b = 4;
    final sealedClassC = SealedClassC()
      ..baseField = 5
      ..c = 6;

    expect(sealedClassA.baseField, 1);
    expect(sealedClassA.a, 2);
    expect(sealedClassB.baseField, 3);
    expect(sealedClassB.b, 4);
    expect(sealedClassC.baseField, 5);
    expect(sealedClassC.c, 6);

    final sealedClassAJson = sealedClassA.toJson();
    final sealedClassBJson = sealedClassB.toJson();
    final sealedClassCJson = sealedClassC.toJson();

    expect(sealedClassAJson['baseField'], 1);
    expect(sealedClassAJson['a'], 2);
    expect(sealedClassBJson['baseField'], 3);
    expect(sealedClassBJson['b'], 4);
    expect(sealedClassCJson['baseField'], 5);
    expect(sealedClassCJson['c'], 6);

    expect(sealedClassAJson['__type'], 'SealedClassA');
    expect(sealedClassBJson['__type'], 'SealedClassB');
    expect(sealedClassCJson['__type'], 'SealedClassC');

    final deserializedSealedClassA = SealedClass.fromJson(sealedClassAJson);
    final deserializedSealedClassB = SealedClass.fromJson(sealedClassBJson);
    final deserializedSealedClassC = SealedClass.fromJson(sealedClassCJson);

    expect(deserializedSealedClassA.baseField, 1);
    expect(deserializedSealedClassA is SealedClassA, true);
    expect((deserializedSealedClassA as SealedClassA).a, 2);
    expect(deserializedSealedClassB.baseField, 3);
    expect(deserializedSealedClassB is SealedClassB, true);
    expect((deserializedSealedClassB as SealedClassB).b, 4);
    expect(deserializedSealedClassC.baseField, 5);
    expect(deserializedSealedClassC is SealedClassC, true);
    expect((deserializedSealedClassC as SealedClassC).c, 6);
  });
}
