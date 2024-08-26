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

import 'package:anthem_codegen/annotations.dart';
import 'package:flutter_test/flutter_test.dart';

part 'sealed_class_serialization_test.g.dart';

@AnthemModel(serializable: true)
sealed class SealedClass extends _SealedClass
    with _$SealedClassAnthemModelMixin {
  SealedClass();

  factory SealedClass.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$SealedClassAnthemModelMixin.fromJson_ANTHEM(json);
}

class _SealedClass {
  late int baseField;
}

class SealedClassA extends SealedClass {
  late int a;
}

class SealedClassB extends SealedClass {
  late int b;
}

class SealedClassC extends SealedClass {
  late int c;
}

void main() {
  test('Test sealed classes', () {
    final sealedClassA = SealedClassA()
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

    final sealedClassAJson = sealedClassA.toJson_ANTHEM();
    final sealedClassBJson = sealedClassB.toJson_ANTHEM();
    final sealedClassCJson = sealedClassC.toJson_ANTHEM();

    expect(sealedClassAJson['baseField'], 1);
    expect(sealedClassAJson['a'], 2);
    expect(sealedClassBJson['baseField'], 3);
    expect(sealedClassBJson['b'], 4);
    expect(sealedClassCJson['baseField'], 5);
    expect(sealedClassCJson['c'], 6);

    expect(sealedClassAJson['__type'], 'SealedClassA');
    expect(sealedClassBJson['__type'], 'SealedClassB');
    expect(sealedClassCJson['__type'], 'SealedClassC');

    final deserializedSealedClassA =
        SealedClass.fromJson_ANTHEM(sealedClassAJson);
    final deserializedSealedClassB =
        SealedClass.fromJson_ANTHEM(sealedClassBJson);
    final deserializedSealedClassC =
        SealedClass.fromJson_ANTHEM(sealedClassCJson);

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
