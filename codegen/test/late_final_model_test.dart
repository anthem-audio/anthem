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

import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

part 'late_final_model_test.g.dart';

@AnthemModel(serializable: true, generateModelSync: true)
class ChildModel extends _ChildModel
    with _$ChildModel, _$ChildModelAnthemModelMixin {
  ChildModel({required super.value});
  ChildModel.uninitialized() : super(value: 0);

  factory ChildModel.fromJson(Map<String, dynamic> json) =>
      _$ChildModelAnthemModelMixin.fromJson(json);
}

abstract class _ChildModel with Store, AnthemModelBase {
  int value;
  _ChildModel({required this.value});
}

@AnthemModel(serializable: true, generateModelSync: true)
class WriteOnceModel extends _WriteOnceModel
    with _$WriteOnceModel, _$WriteOnceModelAnthemModelMixin {
  WriteOnceModel({
    required ChildModel child,
    required ChildModel observedChild,
  }) {
    this.child = child;
    this.observedChild = observedChild;
    label = null;
    attach();
  }
  WriteOnceModel.uninitialized();

  void attach() {
    isTopLevelModel = true;
    setParentPropertiesOnChildren();
  }

  factory WriteOnceModel.fromJson(Map<String, dynamic> json) {
    final model = _$WriteOnceModelAnthemModelMixin.fromJson(json);
    model.attach();
    return model;
  }
}

abstract class _WriteOnceModel with Store, AnthemModelBase {
  @Union([ChildModel])
  late final AnthemModelBase child;

  @anthemObservable
  late final ChildModel observedChild;

  @anthemObservable
  late final String? label;
}

void main() {
  WriteOnceModel makeModel() => WriteOnceModel(
    child: ChildModel(value: 1),
    observedChild: ChildModel(value: 2),
  );

  test('late final fields deserialize once, including a null value', () {
    final original = makeModel();
    final restored = WriteOnceModel.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
    expect(restored.child.parent, same(restored));
    expect(restored.observedChild.parent, same(restored));
    expect(restored.label, isNull);
    expect(() => restored.label = 'replacement', throwsA(isA<Error>()));
    expect(restored.label, isNull);
  });

  test('initializing an observable to null still reports its first write', () {
    final model = WriteOnceModel.uninitialized()..isTopLevelModel = true;
    final changes = <ModelChangeEvent>[];
    model.addRawFieldChangedListener(changes.add);
    var observations = 0;
    final dispose = autorun((_) {
      try {
        model.label;
      } on Error {
        // Reading before the first assignment is still an error.
      }
      observations++;
    });
    addTearDown(dispose.call);

    model.label = null;
    expect(observations, 2);
    expect(changes, hasLength(1));
    expect(model.label, isNull);
  });

  test('reassignment leaves union attachment and descendant sync intact', () {
    final model = makeModel();
    final original = model.child as ChildModel;
    final replacement = ChildModel(value: 3);
    final changes = <ModelChangeEvent>[];
    model.addRawFieldChangedListener(changes.add);

    expect(() => model.child = replacement, throwsA(isA<Error>()));
    expect(model.child, same(original));
    expect(original.parent, same(model));
    expect(replacement.parent, isNull);
    expect(changes, isEmpty);

    original.value = 4;
    expect(changes, hasLength(1));
    expect(changes.single.fieldAccessors.map((a) => a.fieldName), [
      'child',
      'value',
    ]);
    expect(changes.single.sendToEngine, isTrue);
  });

  test('reassignment has no MobX or child lifecycle side effects', () {
    final model = makeModel();
    final original = model.observedChild;
    final replacement = ChildModel(value: 3);
    final changes = <ModelChangeEvent>[];
    model.addRawFieldChangedListener(changes.add);
    var observations = 0;
    final dispose = autorun((_) {
      model.observedChild;
      model.label;
      observations++;
    });
    addTearDown(dispose.call);

    expect(() => model.observedChild = replacement, throwsA(isA<Error>()));
    expect(() => model.label = null, throwsA(isA<Error>()));
    expect(observations, 1);
    expect(changes, isEmpty);
    expect(model.observedChild, same(original));
    expect(original.parent, same(model));
    expect(replacement.parent, isNull);

    original.value = 5;
    expect(changes, hasLength(1));
    expect(changes.single.fieldAccessors.map((a) => a.fieldName), [
      'observedChild',
      'value',
    ]);
  });
}
