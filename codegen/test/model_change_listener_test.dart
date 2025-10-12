/*
  Copyright (C) 2025 Joshua Wade

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

part 'model_change_listener_test.g.dart';

@AnthemModel(serializable: true, generateModelSync: true)
class ModelSubElement extends _ModelSubElement
    with _$ModelSubElement, _$ModelSubElementAnthemModelMixin {
  ModelSubElement({required super.id, required super.value});
  ModelSubElement.uninitialized() : super(id: 0, value: '');

  factory ModelSubElement.fromJson(Map<String, dynamic> json) =>
      _$ModelSubElementAnthemModelMixin.fromJson(json);
}

abstract class _ModelSubElement with Store, AnthemModelBase {
  late int id;
  String? value;
  AnthemObservableMap<String, int> mapOfPrimitives = AnthemObservableMap();

  _ModelSubElement({required this.id, required this.value});
}

@AnthemModel(serializable: true, generateModelSync: true)
class Model extends _Model with _$Model, _$ModelAnthemModelMixin {
  Model({required super.id, required super.name, super.subElement}) {
    _init();
  }
  Model.uninitialized() : super(id: 0, name: '') {
    _init();
  }

  void _init() {
    // These are both only necessary on the top-level model
    isTopLevelModel = true;
    setParentPropertiesOnChildren();
  }

  factory Model.fromJson(Map<String, dynamic> json) =>
      _$ModelAnthemModelMixin.fromJson(json);
}

abstract class _Model with Store, AnthemModelBase {
  late int id;
  String? name;
  ModelSubElement? subElement;

  AnthemObservableList<ModelSubElement> listOfSubElements =
      AnthemObservableList();

  AnthemObservableList<AnthemObservableList<ModelSubElement>>
  listOfListOfSubElements = AnthemObservableList();

  AnthemObservableList<AnthemObservableList<int>> listOfListOfInts =
      AnthemObservableList();

  AnthemObservableMap<String, ModelSubElement> mapOfSubElements =
      AnthemObservableMap();

  AnthemObservableMap<String, AnthemObservableList<ModelSubElement>>
  mapOfListOfSubElements = AnthemObservableMap();

  AnthemObservableList<AnthemObservableMap<String, ModelSubElement>>
  listOfMapOfSubElements = AnthemObservableList();

  AnthemObservableMap<String, AnthemObservableList<int>> mapOfListOfInts =
      AnthemObservableMap();

  _Model({required this.id, required this.name, this.subElement});
}

void main() {
  test('Listen for field changes', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];

    model.onChange((b) => b.name, (e) {
      changes.add(e);
    });

    model.name = 'new name';
    model.name = 'newer name';
    model.name = null;

    // Should not trigger the listener
    model.id = 5;
    model.listOfSubElements.add(ModelSubElement(id: 0, value: 'value'));

    expect(changes.length, 3);

    expect(changes[0].fieldAccessors.first.fieldName, 'name');
    expect(changes[0].operation is RawFieldUpdate, true);
    expect(changes[0].operation.oldValue, 'name');
    expect(changes[0].operation.newValue, 'new name');

    expect(changes[1].operation.oldValue, 'new name');
    expect(changes[1].operation.newValue, 'newer name');

    expect(changes[2].operation.oldValue, 'newer name');
    expect(changes[2].operation.newValue, null);
  });

  test('Listen for field combinations', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changesAllFields = [];
    model.onChange((b) => b.anyField, (e) {
      changesAllFields.add(e);
    });

    List<ModelFilterEvent> changesSomeFields = [];
    model.onChange((b) => b.multiple([(b) => b.name, (b) => b.id]), (e) {
      changesSomeFields.add(e);
    });

    model.name = 'new name';

    expect(changesAllFields.length, 1);
    expect(changesAllFields[0].operation is RawFieldUpdate, true);
    expect(changesAllFields[0].operation.oldValue, 'name');
    expect(changesAllFields[0].operation.newValue, 'new name');

    expect(changesSomeFields.length, 1);
    expect(changesSomeFields[0].operation is RawFieldUpdate, true);
    expect(changesSomeFields[0].operation.oldValue, 'name');
    expect(changesSomeFields[0].operation.newValue, 'new name');

    model.id = 1;

    expect(changesAllFields.length, 2);
    expect(changesAllFields[1].operation is RawFieldUpdate, true);
    expect(changesAllFields[1].operation.oldValue, 0);
    expect(changesAllFields[1].operation.newValue, 1);

    expect(changesSomeFields.length, 2);
    expect(changesSomeFields[1].operation is RawFieldUpdate, true);
    expect(changesSomeFields[1].operation.oldValue, 0);
    expect(changesSomeFields[1].operation.newValue, 1);

    model.subElement = ModelSubElement(id: 0, value: 'value');

    expect(changesAllFields.length, 3);
    expect(changesAllFields[2].operation is RawFieldUpdate, true);
    expect(changesAllFields[2].operation.oldValue, null);
    expect(changesAllFields[2].operation.newValue, isA<ModelSubElement>());

    expect(changesSomeFields.length, 2);
  });

  test('Filter by change type (list)', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];
    model.onChange(
      (b) => b.listOfSubElements.anyElement.filterByChangeType([
        ModelFilterChangeType.fieldUpdate,
        ModelFilterChangeType.listInsert,
      ]),
      (e) {
        changes.add(e);
      },
    );

    model.listOfSubElements = AnthemObservableList.of([]);

    expect(changes.length, 0);

    model.listOfSubElements.add(ModelSubElement(id: 0, value: 'value'));

    expect(changes.length, 1);
    expect(changes[0].operation, isA<ListInsert>());

    model.listOfSubElements.removeAt(0);

    expect(changes.length, 1);
  });

  test('Listen for sub-element field changes', () {
    final model = Model(
      id: 0,
      name: 'name',
      subElement: ModelSubElement(id: 1, value: 'value'),
    );

    List<ModelFilterEvent> changes = [];
    model.onChange((b) => b.subElement.value, (e) {
      changes.add(e);
    });

    model.subElement!.value = 'new value';
    model.subElement!.value = null;

    // Should not trigger the listener
    model.subElement!.id = 5;
    model.name = 'new name';

    expect(changes.length, 2);
    expect(changes[0].operation.oldValue, 'value');
    expect(changes[0].operation.newValue, 'new value');
    expect(changes[1].operation.oldValue, 'new value');
    expect(changes[1].operation.newValue, null);
  });

  test('Listen for changes in list elements', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];
    model.onChange((b) => b.listOfSubElements.anyElement.value, (e) {
      changes.add(e);
    });

    final subElement = ModelSubElement(id: 1, value: 'value');
    model.listOfSubElements.add(subElement);
    subElement.value = 'new value';
    subElement.value = null;
    model.listOfSubElements.removeAt(0);
    model.name = 'should not trigger';

    expect(changes.length, 2);
    expect(changes[0].operation.oldValue, 'value');
    expect(changes[0].operation.newValue, 'new value');
    expect(changes[1].operation.oldValue, 'new value');
    expect(changes[1].operation.newValue, null);
  });

  test(
    'Listening to an item should not automatically listen to distant descendant changes',
    () {
      final model = Model(id: 0, name: 'name');

      List<ModelFilterEvent> changes = [];
      model.onChange((b) => b.listOfSubElements.anyElement, (e) {
        changes.add(e);
      });

      final subElement = ModelSubElement(id: 1, value: 'value');
      model.listOfSubElements.add(subElement);
      subElement.value = 'new value';
      subElement.value = null;
      model.listOfSubElements.removeAt(0);

      expect(changes.length, 2);
      expect(changes[0].operation, isA<ListInsert>());
      expect(changes[1].operation, isA<ListRemove>());
    },
  );

  test('Listen for nested list model field changes', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];
    model.onChange(
      (b) => b.listOfListOfSubElements.anyElement.anyElement.value,
      (e) {
        changes.add(e);
      },
    );

    final innerList = AnthemObservableList.of([
      ModelSubElement(id: 1, value: 'value'),
    ]);

    model.listOfListOfSubElements.add(innerList);

    innerList[0].value = 'new value';
    innerList[0].value = null;

    model.listOfListOfSubElements.removeAt(0);

    expect(changes.length, 2);
    expect(changes[0].operation.oldValue, 'value');
    expect(changes[0].operation.newValue, 'new value');
    expect(changes[1].operation.oldValue, 'new value');
    expect(changes[1].operation.newValue, null);
  });

  test('Listen for nested list primitive changes', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];
    model.onChange(
      (b) => b
          .multiple([
            (b) => b.listOfListOfInts.anyElement,
            (b) => b.listOfListOfInts.anyElement.anyElement,
          ])
          .filterByChangeType([
            ModelFilterChangeType.listInsert,
            ModelFilterChangeType.listUpdate,
            ModelFilterChangeType.listRemove,
          ]),
      (e) {
        changes.add(e);
      },
    );

    final innerList = AnthemObservableList.of([1, 2]);

    model.listOfListOfInts.add(innerList);

    expect(changes.length, 1);
    expect(changes[0].operation, isA<ListInsert>());

    innerList[0] = 5;

    expect(changes.length, 2);
    expect(changes[1].operation, isA<ListUpdate>());
    final listUpdate = changes[1].operation as ListUpdate;
    expect(listUpdate.oldValue, 1);
    expect(listUpdate.newValue, 5);

    innerList.removeAt(0);

    expect(changes.length, 3);
    expect(changes[2].operation, isA<ListRemove>());
  });

  test('Listen for map value changes', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];
    model.onChange((b) => b.mapOfSubElements.anyValue.value, (e) {
      changes.add(e);
    });

    final subElement = ModelSubElement(id: 1, value: 'value');
    model.mapOfSubElements['one'] = subElement;
    subElement.value = 'new value';
    subElement.value = null;
    model.mapOfSubElements.remove('one');

    expect(changes.length, 2);
    expect(changes[0].operation.oldValue, 'value');
    expect(changes[0].operation.newValue, 'new value');
    expect(changes[1].operation.oldValue, 'new value');
    expect(changes[1].operation.newValue, null);
  });

  test('Listen for nested map list model field changes', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];
    model.onChange((b) => b.mapOfListOfSubElements.anyValue.anyElement.value, (
      e,
    ) {
      changes.add(e);
    });

    final innerList = AnthemObservableList.of([
      ModelSubElement(id: 1, value: 'value'),
    ]);

    model.mapOfListOfSubElements['one'] = innerList;

    innerList[0].value = 'new value';
    innerList[0].value = null;

    model.mapOfListOfSubElements.remove('one');

    expect(changes.length, 2);
    expect(changes[0].operation.oldValue, 'value');
    expect(changes[0].operation.newValue, 'new value');
    expect(changes[1].operation.oldValue, 'new value');
    expect(changes[1].operation.newValue, null);
  });

  test('Listen for list of map model field changes', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];
    model.onChange((b) => b.listOfMapOfSubElements.anyElement.anyValue.value, (
      e,
    ) {
      changes.add(e);
    });

    final innerMap = AnthemObservableMap.of({
      'one': ModelSubElement(id: 1, value: 'value'),
    });

    model.listOfMapOfSubElements.add(innerMap);

    innerMap['one']!.value = 'new value';
    innerMap['one']!.value = null;

    model.listOfMapOfSubElements.removeAt(0);

    expect(changes.length, 2);
    expect(changes[0].operation.oldValue, 'value');
    expect(changes[0].operation.newValue, 'new value');
    expect(changes[1].operation.oldValue, 'new value');
    expect(changes[1].operation.newValue, null);
  });

  test('Filter by change type (map)', () {
    final model = Model(id: 0, name: 'name');

    List<ModelFilterEvent> changes = [];
    model.onChange(
      (b) => b.mapOfListOfInts.anyValue.filterByChangeType([
        ModelFilterChangeType.mapPut,
        ModelFilterChangeType.mapRemove,
      ]),
      (e) {
        changes.add(e);
      },
    );

    final innerList = AnthemObservableList.of([1, 2]);

    model.mapOfListOfInts['one'] = innerList;

    expect(changes.length, 1);
    expect(changes[0].operation, isA<MapPut>());

    model.mapOfListOfInts.remove('one');

    expect(changes.length, 2);
    expect(changes[1].operation, isA<MapRemove>());
  });
}
