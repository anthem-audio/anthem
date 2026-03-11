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

part 'hide_but_allow_on_change_test.g.dart';

@AnthemModel(serializable: true, generateModelSync: true)
class HiddenOnChangeLeafModel extends _HiddenOnChangeLeafModel
    with _$HiddenOnChangeLeafModel, _$HiddenOnChangeLeafModelAnthemModelMixin {
  HiddenOnChangeLeafModel({required super.id, required super.value});
  HiddenOnChangeLeafModel.uninitialized() : super(id: 0, value: '');

  factory HiddenOnChangeLeafModel.fromJson(Map<String, dynamic> json) =>
      _$HiddenOnChangeLeafModelAnthemModelMixin.fromJson(json);
}

abstract class _HiddenOnChangeLeafModel with Store, AnthemModelBase {
  late int id;
  String? value;

  _HiddenOnChangeLeafModel({required this.id, required this.value});
}

@AnthemModel(serializable: true, generateModelSync: true)
class HiddenOnChangeRootModel extends _HiddenOnChangeRootModel
    with _$HiddenOnChangeRootModel, _$HiddenOnChangeRootModelAnthemModelMixin {
  HiddenOnChangeRootModel({
    required super.id,
    super.visibleValue,
    super.fullyHiddenValue,
    super.hiddenOnChangeValue,
    super.hiddenLeaf,
  }) {
    _init();
  }

  HiddenOnChangeRootModel.uninitialized() : super(id: 0) {
    _init();
  }

  void _init() {
    isTopLevelModel = true;
    setParentPropertiesOnChildren();
  }

  factory HiddenOnChangeRootModel.fromJson(Map<String, dynamic> json) =>
      _$HiddenOnChangeRootModelAnthemModelMixin.fromJson(json);
}

abstract class _HiddenOnChangeRootModel with Store, AnthemModelBase {
  late int id;
  String? visibleValue;

  @anthemObservable
  @hide
  String? fullyHiddenValue;

  @hideButAllowOnChange
  String? hiddenOnChangeValue;

  @hideButAllowOnChange
  HiddenOnChangeLeafModel? hiddenLeaf;

  @hideButAllowOnChange
  AnthemObservableList<HiddenOnChangeLeafModel> hiddenLeaves =
      AnthemObservableList();

  _HiddenOnChangeRootModel({
    required this.id,
    this.visibleValue,
    this.fullyHiddenValue,
    this.hiddenOnChangeValue,
    this.hiddenLeaf,
  });
}

void main() {
  group('@hideButAllowOnChange', () {
    late HiddenOnChangeRootModel model;

    setUp(() {
      model = HiddenOnChangeRootModel(
        id: 1,
        visibleValue: 'visible',
        fullyHiddenValue: 'fully hidden',
        hiddenOnChangeValue: 'hidden onChange',
      );
    });

    test('plain hide fields stay out of the model change stream', () {
      final changes = <ModelChangeEvent>[];

      model.addRawFieldChangedListener(changes.add);

      model.fullyHiddenValue = 'updated';

      expect(changes, isEmpty);
    });

    test('direct field writes stay observable and suppress engine sync', () {
      final changes = <ModelChangeEvent>[];

      model.onChange((b) => b.hiddenOnChangeValue, changes.add);

      model.hiddenOnChangeValue = 'updated hidden value';

      expect(changes, hasLength(1));
      expect(changes.single.sendToEngine, isFalse);
      expect(changes.single.fieldAccessors.map((a) => a.fieldName), [
        'hiddenOnChangeValue',
      ]);
      expect(changes.single.operation, isA<RawFieldUpdate>());
      expect(
        (changes.single.operation as RawFieldUpdate).newValue,
        'updated hidden value',
      );
    });

    test('fields stay hidden from both project and engine JSON', () {
      model.hiddenLeaf = HiddenOnChangeLeafModel(id: 2, value: 'leaf');
      model.hiddenLeaves.add(HiddenOnChangeLeafModel(id: 3, value: 'list'));

      final projectJson = model.toJson(forProjectFile: true, forEngine: false);
      final engineJson = model.toJson(forProjectFile: false, forEngine: true);

      expect(projectJson.containsKey('fullyHiddenValue'), isFalse);
      expect(projectJson.containsKey('hiddenOnChangeValue'), isFalse);
      expect(projectJson.containsKey('hiddenLeaf'), isFalse);
      expect(projectJson.containsKey('hiddenLeaves'), isFalse);

      expect(engineJson.containsKey('fullyHiddenValue'), isFalse);
      expect(engineJson.containsKey('hiddenOnChangeValue'), isFalse);
      expect(engineJson.containsKey('hiddenLeaf'), isFalse);
      expect(engineJson.containsKey('hiddenLeaves'), isFalse);
    });

    test(
      'descendant listeners see hidden ancestor suppression immediately',
      () {
        model.hiddenLeaf = HiddenOnChangeLeafModel(id: 2, value: 'leaf');
        final hiddenLeaf = model.hiddenLeaf!;

        ModelChangeEvent? leafChange;
        ModelChangeEvent? rootChange;

        hiddenLeaf.addRawFieldChangedListener((change) {
          leafChange = change;
        });
        model.addRawFieldChangedListener((change) {
          if (change.fieldAccessors.last.fieldName == 'value') {
            rootChange = change;
          }
        });

        hiddenLeaf.value = 'updated leaf';

        expect(leafChange, isNotNull);
        expect(rootChange, isNotNull);
        expect(leafChange!.sendToEngine, isFalse);
        expect(rootChange!.sendToEngine, isFalse);
        expect(rootChange!.fieldAccessors.map((a) => a.fieldName), [
          'hiddenLeaf',
          'value',
        ]);
      },
    );

    test('filters can observe descendants of hidden collections', () {
      model.hiddenLeaves.add(HiddenOnChangeLeafModel(id: 4, value: 'item'));
      final hiddenLeaf = model.hiddenLeaves.first;
      final changes = <ModelChangeEvent>[];

      model.onChange((b) => b.hiddenLeaves.anyElement.value, changes.add);

      hiddenLeaf.value = 'updated item';

      expect(changes, hasLength(1));
      expect(changes.single.sendToEngine, isFalse);
      expect(changes.single.fieldAccessors.map((a) => a.fieldName), [
        'hiddenLeaves',
        null,
        'value',
      ]);
    });
  });
}
