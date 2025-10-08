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

part 'model_sync_test.g.dart';

@AnthemModel(serializable: true, generateModelSync: true)
class ModelSyncTestSubElement extends _ModelSyncTestSubElement
    with _$ModelSyncTestSubElement, _$ModelSyncTestSubElementAnthemModelMixin {
  ModelSyncTestSubElement({required super.id, required super.value});
  ModelSyncTestSubElement.uninitialized() : super(id: 0, value: '');

  factory ModelSyncTestSubElement.fromJson(Map<String, dynamic> json) =>
      _$ModelSyncTestSubElementAnthemModelMixin.fromJson(json);
}

abstract class _ModelSyncTestSubElement with Store, AnthemModelBase {
  late int id;
  String? value;
  AnthemObservableMap<String, int> mapOfPrimitives = AnthemObservableMap();

  _ModelSyncTestSubElement({required this.id, required this.value});
}

@AnthemModel(serializable: true, generateModelSync: true)
class ModelSyncTest extends _ModelSyncTest
    with _$ModelSyncTest, _$ModelSyncTestAnthemModelMixin {
  ModelSyncTest({required super.id, required super.name, super.subElement}) {
    _init();
  }
  ModelSyncTest.uninitialized() : super(id: 0, name: '') {
    _init();
  }

  void _init() {
    // These are both only necessary on the top-level model
    isTopLevelModel = true;
    setParentPropertiesOnChildren();
  }

  factory ModelSyncTest.fromJson(Map<String, dynamic> json) =>
      _$ModelSyncTestAnthemModelMixin.fromJson(json);
}

abstract class _ModelSyncTest with Store, AnthemModelBase {
  late int id;
  String? name;
  ModelSyncTestSubElement? subElement;
  AnthemObservableList<ModelSyncTestSubElement> listOfSubElements =
      AnthemObservableList();

  _ModelSyncTest({required this.id, required this.name, this.subElement});
}

void main() {
  group('Model change descriptions', () {
    final model = ModelSyncTest(id: 1, name: 'Test Model');

    List<(Iterable<FieldAccessor> accessors, FieldOperation operation)>
    changes = [];
    model.addRawFieldChangedListener((accessors, operation) {
      changes.add((accessors, operation));
    });

    setUp(() {
      changes.clear();
    });

    test('Non-nullable field change', () {
      model.id = 2;
      expect(changes, isNotEmpty);
      final (accessors, operation) = changes[0];

      expect(accessors.length, 1);
      expect(accessors.first.fieldName, 'id');
      expect(accessors.first.fieldType, FieldType.raw);

      expect(operation, isA<RawFieldUpdate>());
      final update = operation as RawFieldUpdate;
      expect(update.oldValue, 1);
      expect(update.newValue, 2);
      expect(update.newValueSerialized, 2);
    });

    test('Nullable field change', () {
      model.name = 'New Name';
      expect(changes, isNotEmpty);
      final (accessors, operation) = changes[0];

      expect(accessors.length, 1);
      expect(accessors.first.fieldName, 'name');
      expect(accessors.first.fieldType, FieldType.raw);

      expect(operation, isA<RawFieldUpdate>());
      final update = operation as RawFieldUpdate;
      expect(update.oldValue, 'Test Model');
      expect(update.newValue, 'New Name');
      expect(update.newValueSerialized, 'New Name');
    });

    test('Nullable field set to null', () {
      model.name = null;
      expect(changes, isNotEmpty);
      final (accessors, operation) = changes[0];

      expect(accessors.length, 1);
      expect(accessors.first.fieldName, 'name');
      expect(accessors.first.fieldType, FieldType.raw);

      expect(operation, isA<RawFieldUpdate>());
      final update = operation as RawFieldUpdate;
      expect(update.oldValue, 'New Name');
      expect(update.newValue, null);
      expect(update.newValueSerialized, null);
    });

    test('Nested model set to initial value', () {
      model.subElement = ModelSyncTestSubElement(id: 1, value: 'Sub Element');
      expect(changes, isNotEmpty);
      final (accessors, operation) = changes[0];

      expect(accessors.length, 1);
      expect(accessors.first.fieldName, 'subElement');
      expect(accessors.first.fieldType, FieldType.raw);

      expect(operation, isA<RawFieldUpdate>());
      final update = operation as RawFieldUpdate;
      expect(update.oldValue, null);
      expect(update.newValue, isA<ModelSyncTestSubElement>());
      expect((update.newValue as ModelSyncTestSubElement).id, 1);
      expect((update.newValue as ModelSyncTestSubElement).value, 'Sub Element');
      expect(update.newValueSerialized, {
        'id': 1,
        'value': 'Sub Element',
        'mapOfPrimitives': {},
      });
    });

    test('Nested model field change', () {
      model.subElement?.value = 'Updated Value';
      expect(changes, isNotEmpty);
      final (accessors, operation) = changes[0];

      expect(accessors.length, 2);
      expect(accessors.elementAt(0).fieldName, 'subElement');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).fieldName, 'value');
      expect(accessors.elementAt(1).fieldType, FieldType.raw);

      expect(operation, isA<RawFieldUpdate>());
      final update = operation as RawFieldUpdate;
      expect(update.oldValue, 'Sub Element');
      expect(update.newValue, 'Updated Value');
      expect(update.newValueSerialized, 'Updated Value');
    });

    test('Updates still work when subElement is provided in constructor', () {
      final model2 = ModelSyncTest(
        id: 3,
        name: 'Model 2',
        subElement: ModelSyncTestSubElement(id: 2, value: 'Initial'),
      );

      List<(Iterable<FieldAccessor> accessors, FieldOperation operation)>
      changes2 = [];
      model2.addRawFieldChangedListener((accessors, operation) {
        changes2.add((accessors, operation));
      });

      model2.subElement?.value = 'Changed';
      expect(changes2.length, 1);
      final (accessors, operation) = changes2[0];

      expect(accessors.length, 2);
      expect(accessors.elementAt(0).fieldName, 'subElement');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).fieldName, 'value');
      expect(accessors.elementAt(1).fieldType, FieldType.raw);

      expect(operation, isA<RawFieldUpdate>());
      final update = operation as RawFieldUpdate;
      expect(update.oldValue, 'Initial');
      expect(update.newValue, 'Changed');
      expect(update.newValueSerialized, 'Changed');
    });

    test('List of nested models', () {
      final subElement1 = ModelSyncTestSubElement(id: 1, value: 'Item 1');
      final subElement2 = ModelSyncTestSubElement(id: 2, value: 'Item 2');
      final subElement3 = ModelSyncTestSubElement(id: 3, value: 'Item 3');

      model.listOfSubElements.add(subElement1);
      expect(changes, isNotEmpty);
      var (accessors, operation) = changes[0];

      expect(accessors.length, 2);
      expect(accessors.elementAt(0).fieldName, 'listOfSubElements');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).index, 0);
      expect(accessors.elementAt(1).fieldType, FieldType.list);

      {
        expect(operation, isA<ListInsert>());
        var update = operation as ListInsert;
        expect(update.value, isA<ModelSyncTestSubElement>());
        expect((update.value as ModelSyncTestSubElement).id, 1);
      }

      changes.clear();
      model.listOfSubElements[0] = subElement2;
      expect(changes, isNotEmpty);
      (accessors, operation) = changes.last;

      expect(accessors.length, 2);
      expect(accessors.elementAt(0).fieldName, 'listOfSubElements');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).index, 0);
      expect(accessors.elementAt(1).fieldType, FieldType.list);

      {
        expect(operation, isA<ListUpdate>());
        var update = operation as ListUpdate;
        expect(update.oldValue, isA<ModelSyncTestSubElement>());
        expect((update.oldValue as ModelSyncTestSubElement).id, 1);
        expect(update.newValue, isA<ModelSyncTestSubElement>());
        expect((update.newValue as ModelSyncTestSubElement).id, 2);
        expect(update.newValueSerialized, {
          'id': 2,
          'value': 'Item 2',
          'mapOfPrimitives': {},
        });
      }

      changes.clear();
      model.listOfSubElements.insert(0, subElement3);
      expect(changes, isNotEmpty);
      (accessors, operation) = changes.last;

      expect(accessors.length, 2);
      expect(accessors.elementAt(0).fieldName, 'listOfSubElements');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).index, 0);
      expect(accessors.elementAt(1).fieldType, FieldType.list);

      {
        expect(operation, isA<ListInsert>());
        var update = operation as ListInsert;
        expect(update.value, isA<ModelSyncTestSubElement>());
        expect((update.value as ModelSyncTestSubElement).id, 3);
      }

      expect(model.listOfSubElements.length, 2);
      expect(model.listOfSubElements[0].id, 3);
      expect(model.listOfSubElements[1].id, 2);

      changes.clear();
      model.listOfSubElements.removeAt(1);
      expect(changes, isNotEmpty);
      (accessors, operation) = changes.last;

      expect(accessors.length, 2);
      expect(accessors.elementAt(0).fieldName, 'listOfSubElements');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).index, 1);
      expect(accessors.elementAt(1).fieldType, FieldType.list);

      {
        expect(operation, isA<ListRemove>());
        var update = operation as ListRemove;
        expect(update.removedValue, isA<ModelSyncTestSubElement>());
        expect((update.removedValue as ModelSyncTestSubElement).id, 2);
      }

      changes.clear();
      model.listOfSubElements[0].value = 'Updated Item 3';
      expect(changes, isNotEmpty);
      (accessors, operation) = changes.last;

      expect(accessors.length, 3);
      expect(accessors.elementAt(0).fieldName, 'listOfSubElements');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).index, 0);
      expect(accessors.elementAt(1).fieldType, FieldType.list);
      expect(accessors.elementAt(2).fieldName, 'value');
      expect(accessors.elementAt(2).fieldType, FieldType.raw);

      {
        expect(operation, isA<RawFieldUpdate>());
        var update = operation as RawFieldUpdate;
        expect(update.oldValue, 'Item 3');
        expect(update.newValue, 'Updated Item 3');
        expect(update.newValueSerialized, 'Updated Item 3');
      }
    });

    test('Map of primitives', () {
      model.subElement?.mapOfPrimitives['one'] = 1;
      expect(changes, isNotEmpty);
      var (accessors, operation) = changes[0];

      expect(accessors.length, 3);
      expect(accessors.elementAt(0).fieldName, 'subElement');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).fieldName, 'mapOfPrimitives');
      expect(accessors.elementAt(1).fieldType, FieldType.raw);
      expect(accessors.elementAt(2).key, 'one');
      expect(accessors.elementAt(2).fieldType, FieldType.map);

      {
        expect(operation, isA<MapPut>());
        var update = operation as MapPut;
        expect(update.oldValue, null);
        expect(update.newValue, 1);
        expect(update.newValueSerialized, 1);
      }

      changes.clear();
      model.subElement?.mapOfPrimitives['one'] = 11;
      expect(changes, isNotEmpty);
      (accessors, operation) = changes.last;

      expect(accessors.length, 3);
      expect(accessors.elementAt(0).fieldName, 'subElement');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).fieldName, 'mapOfPrimitives');
      expect(accessors.elementAt(1).fieldType, FieldType.raw);
      expect(accessors.elementAt(2).key, 'one');
      expect(accessors.elementAt(2).fieldType, FieldType.map);

      {
        expect(operation, isA<MapPut>());
        var update = operation as MapPut;
        expect(update.oldValue, 1);
        expect(update.newValue, 11);
        expect(update.newValueSerialized, 11);
      }

      changes.clear();
      model.subElement?.mapOfPrimitives['two'] = 2;
      expect(changes, isNotEmpty);
      (accessors, operation) = changes.last;

      expect(accessors.length, 3);
      expect(accessors.elementAt(0).fieldName, 'subElement');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).fieldName, 'mapOfPrimitives');
      expect(accessors.elementAt(1).fieldType, FieldType.raw);
      expect(accessors.elementAt(2).key, 'two');
      expect(accessors.elementAt(2).fieldType, FieldType.map);

      {
        expect(operation, isA<MapPut>());
        var update = operation as MapPut;
        expect(update.oldValue, null);
        expect(update.newValue, 2);
        expect(update.newValueSerialized, 2);
      }

      changes.clear();
      model.subElement?.mapOfPrimitives.remove('one');
      expect(changes, isNotEmpty);
      (accessors, operation) = changes.last;

      expect(accessors.length, 3);
      expect(accessors.elementAt(0).fieldName, 'subElement');
      expect(accessors.elementAt(0).fieldType, FieldType.raw);
      expect(accessors.elementAt(1).fieldName, 'mapOfPrimitives');
      expect(accessors.elementAt(1).fieldType, FieldType.raw);
      expect(accessors.elementAt(2).key, 'one');
      expect(accessors.elementAt(2).fieldType, FieldType.map);

      {
        expect(operation, isA<MapRemove>());
        var update = operation as MapRemove;
        expect(update.removedValue, 11);
      }
    });
  });
}
