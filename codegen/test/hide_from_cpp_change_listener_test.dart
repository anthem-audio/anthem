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

part 'hide_from_cpp_change_listener_test.g.dart';

@AnthemModel(serializable: true, generateModelSync: true)
class HiddenLeafModel extends _HiddenLeafModel
    with _$HiddenLeafModel, _$HiddenLeafModelAnthemModelMixin {
  HiddenLeafModel({required super.id, required super.value});
  HiddenLeafModel.uninitialized() : super(id: 0, value: '');

  factory HiddenLeafModel.fromJson(Map<String, dynamic> json) =>
      _$HiddenLeafModelAnthemModelMixin.fromJson(json);
}

abstract class _HiddenLeafModel with Store, AnthemModelBase {
  late int id;
  String? value;

  _HiddenLeafModel({required this.id, required this.value});
}

@AnthemModel(serializable: true, generateModelSync: true)
class HiddenRootModel extends _HiddenRootModel
    with _$HiddenRootModel, _$HiddenRootModelAnthemModelMixin {
  HiddenRootModel({
    required super.id,
    super.visibleValue,
    super.hiddenValue,
    super.hiddenLeaf,
  }) {
    _init();
  }

  HiddenRootModel.uninitialized() : super(id: 0) {
    _init();
  }

  void _init() {
    isTopLevelModel = true;
    setParentPropertiesOnChildren();
  }

  factory HiddenRootModel.fromJson(Map<String, dynamic> json) =>
      _$HiddenRootModelAnthemModelMixin.fromJson(json);
}

abstract class _HiddenRootModel with Store, AnthemModelBase {
  late int id;
  String? visibleValue;

  @hideFromCpp
  String? hiddenValue;

  @hideFromCpp
  HiddenLeafModel? hiddenLeaf;

  @hideFromCpp
  AnthemObservableList<HiddenLeafModel> hiddenLeaves = AnthemObservableList();

  _HiddenRootModel({
    required this.id,
    this.visibleValue,
    this.hiddenValue,
    this.hiddenLeaf,
  });
}

void main() {
  group('@hideFromCpp change listeners', () {
    late HiddenRootModel model;

    setUp(() {
      model = HiddenRootModel(
        id: 1,
        visibleValue: 'visible',
        hiddenValue: 'hidden',
      );
    });

    test('direct field writes stay observable and suppress engine sync', () {
      final changes = <ModelChangeEvent>[];

      model.onChange((b) => b.hiddenValue, changes.add);

      model.hiddenValue = 'updated hidden value';

      expect(changes, hasLength(1));
      expect(changes.single.sendToEngine, isFalse);
      expect(changes.single.fieldAccessors.map((a) => a.fieldName), [
        'hiddenValue',
      ]);
      expect(changes.single.operation, isA<RawFieldUpdate>());
      expect(
        (changes.single.operation as RawFieldUpdate).newValue,
        'updated hidden value',
      );
    });

    test('visible fields still request engine sync', () {
      final changes = <ModelChangeEvent>[];

      model.onChange((b) => b.visibleValue, changes.add);

      model.visibleValue = 'updated visible value';

      expect(changes, hasLength(1));
      expect(changes.single.sendToEngine, isTrue);
    });

    test(
      'descendant listeners see hidden ancestor suppression immediately',
      () {
        model.hiddenLeaf = HiddenLeafModel(id: 2, value: 'leaf');
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

    test(
      'hidden collection mutations stay observable and suppress engine sync',
      () {
        final rawChanges = <ModelChangeEvent>[];

        model.addRawFieldChangedListener(rawChanges.add);

        model.hiddenLeaves.add(HiddenLeafModel(id: 3, value: 'list item'));

        expect(rawChanges, hasLength(1));
        expect(rawChanges.single.sendToEngine, isFalse);
        expect(rawChanges.single.operation, isA<ListInsert>());
        expect(rawChanges.single.fieldAccessors.map((a) => a.fieldName), [
          'hiddenLeaves',
          null,
        ]);
      },
    );

    test('filters can observe descendants of hideFromCpp collections', () {
      model.hiddenLeaves.add(HiddenLeafModel(id: 4, value: 'item'));
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
