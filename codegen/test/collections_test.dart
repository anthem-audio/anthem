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

enum TestEnum { first, second }

class TestModel with AnthemModelBase {
  TestModel(this.value, {this.childList, this.childMap});

  String value;
  final AnthemObservableList<Object?>? childList;
  final AnthemObservableMap<Object?, Object?>? childMap;

  int setParentPropertiesOnChildrenCallCount = 0;

  void emitValueChange(String newValue) {
    final oldValue = value;
    value = newValue;

    notifyFieldChanged(
      operation: RawFieldUpdate(
        oldValue: oldValue,
        newValue: newValue,
        newValueSerialized: newValue,
      ),
      accessorChain: [
        FieldAccessor(fieldType: FieldType.raw, fieldName: 'value'),
      ],
    );
  }

  @override
  Map<String, Object?> toJson({
    bool forEngine = false,
    bool forProjectFile = true,
  }) {
    return {
      'value': value,
      'forEngine': forEngine,
      'forProjectFile': forProjectFile,
      if (childList != null)
        'childList': childList!.toJson(
          forEngine: forEngine,
          forProjectFile: forProjectFile,
        ),
      if (childMap != null)
        'childMap': childMap!.toJson(
          forEngine: forEngine,
          forProjectFile: forProjectFile,
        ),
    };
  }

  @override
  void setParentPropertiesOnChildren() {
    setParentPropertiesOnChildrenCallCount++;

    childList?.setParentProperties(
      parent: this,
      fieldType: FieldType.raw,
      fieldName: 'childList',
    );
    childMap?.setParentProperties(
      parent: this,
      fieldType: FieldType.raw,
      fieldName: 'childMap',
    );
  }
}

class TestRoot with AnthemModelBase {
  TestRoot({
    AnthemObservableList<Object?>? list,
    AnthemObservableMap<Object?, Object?>? map,
  }) : list = list ?? AnthemObservableList<Object?>(),
       map = map ?? AnthemObservableMap<Object?, Object?>() {
    isTopLevelModel = true;
    setParentPropertiesOnChildren();
  }

  final AnthemObservableList<Object?> list;
  final AnthemObservableMap<Object?, Object?> map;

  @override
  Map<String, Object?> toJson({
    bool forEngine = false,
    bool forProjectFile = true,
  }) {
    return {
      'list': list.toJson(forEngine: forEngine, forProjectFile: forProjectFile),
      'map': map.toJson(forEngine: forEngine, forProjectFile: forProjectFile),
    };
  }

  @override
  void setParentPropertiesOnChildren() {
    list.setParentProperties(
      parent: this,
      fieldType: FieldType.raw,
      fieldName: 'list',
    );
    map.setParentProperties(
      parent: this,
      fieldType: FieldType.raw,
      fieldName: 'map',
    );
  }
}

Map<String, Object?> _serializedModel(
  String value, {
  required bool forEngine,
  required bool forProjectFile,
}) {
  return {
    'value': value,
    'forEngine': forEngine,
    'forProjectFile': forProjectFile,
  };
}

void _expectRootListAccessor(ModelChangeEvent change, int index) {
  expect(change.fieldAccessors, hasLength(2));
  expect(change.fieldAccessors[0].fieldType, FieldType.raw);
  expect(change.fieldAccessors[0].fieldName, 'list');
  expect(change.fieldAccessors[1].fieldType, FieldType.list);
  expect(change.fieldAccessors[1].index, index);
}

void _expectRootMapAccessor(ModelChangeEvent change, Object? key) {
  expect(change.fieldAccessors, hasLength(2));
  expect(change.fieldAccessors[0].fieldType, FieldType.raw);
  expect(change.fieldAccessors[0].fieldName, 'map');
  expect(change.fieldAccessors[1].fieldType, FieldType.map);
  expect(change.fieldAccessors[1].key, key);
}

void main() {
  group('AnthemObservableList serialization', () {
    test('Serializes supported values recursively and forwards flags', () {
      final list = AnthemObservableList<Object?>.of([
        'text',
        1,
        2.5,
        true,
        null,
        TestEnum.second,
        TestModel('model'),
        AnthemObservableList<Object?>.of([
          TestEnum.first,
          TestModel('nested list model'),
        ]),
        AnthemObservableMap<Object?, Object?>.of({
          TestEnum.first: TestModel('nested map model'),
        }),
      ]);

      expect(list.toJson(), [
        'text',
        1,
        2.5,
        true,
        null,
        'second',
        _serializedModel('model', forEngine: false, forProjectFile: true),
        [
          'first',
          _serializedModel(
            'nested list model',
            forEngine: false,
            forProjectFile: true,
          ),
        ],
        {
          'first': _serializedModel(
            'nested map model',
            forEngine: false,
            forProjectFile: true,
          ),
        },
      ]);

      expect(list.toJson(forEngine: true, forProjectFile: false), [
        'text',
        1,
        2.5,
        true,
        null,
        'second',
        _serializedModel('model', forEngine: true, forProjectFile: false),
        [
          'first',
          _serializedModel(
            'nested list model',
            forEngine: true,
            forProjectFile: false,
          ),
        ],
        {
          'first': _serializedModel(
            'nested map model',
            forEngine: true,
            forProjectFile: false,
          ),
        },
      ]);
    });

    test('Throws for unsupported values', () {
      expect(
        () => AnthemObservableList<Object?>.of([Object()]).toJson(),
        throwsArgumentError,
      );
    });
  });

  group('AnthemObservableList change events', () {
    test('Attaches children when a detached list is attached to a parent', () {
      final child = TestModel('child');
      final list = AnthemObservableList<Object?>.of([child]);

      expect(child.parent, isNull);

      final root = TestRoot(list: list);

      expect(list.parent, same(root));
      expect(child.parent, same(list));
      expect(child.parentFieldType, FieldType.list);
      expect(child.parentListIndex, 0);
      expect(child.setParentPropertiesOnChildrenCallCount, 1);
    });

    test('Element mutations emit operations and maintain parent metadata', () {
      final root = TestRoot();
      final changes = <ModelChangeEvent>[];
      root.addRawFieldChangedListener(changes.add);

      final first = TestModel('first');
      root.list.add(first);

      expect(first.parent, same(root.list));
      expect(first.parentFieldType, FieldType.list);
      expect(first.parentListIndex, 0);
      expect(changes, hasLength(1));
      _expectRootListAccessor(changes.single, 0);
      expect(changes.single.operation, isA<ListInsert>());
      var insert = changes.single.operation as ListInsert;
      expect(insert.value, same(first));
      expect(
        insert.valueSerialized,
        _serializedModel('first', forEngine: true, forProjectFile: false),
      );

      changes.clear();
      final inserted = TestModel('inserted');
      root.list.insert(0, inserted);

      expect(inserted.parent, same(root.list));
      expect(inserted.parentListIndex, 0);
      expect(first.parentListIndex, 1);
      expect(changes, hasLength(1));
      _expectRootListAccessor(changes.single, 0);
      expect(changes.single.operation, isA<ListInsert>());
      insert = changes.single.operation as ListInsert;
      expect(insert.value, same(inserted));

      changes.clear();
      final replacement = TestModel('replacement');
      root.list[1] = replacement;

      expect(first.parent, isNull);
      expect(replacement.parent, same(root.list));
      expect(replacement.parentListIndex, 1);
      expect(changes, hasLength(1));
      _expectRootListAccessor(changes.single, 1);
      expect(changes.single.operation, isA<ListUpdate>());
      final update = changes.single.operation as ListUpdate;
      expect(update.oldValue, same(first));
      expect(update.newValue, same(replacement));
      expect(
        update.newValueSerialized,
        _serializedModel('replacement', forEngine: true, forProjectFile: false),
      );

      changes.clear();
      root.list.removeAt(0);

      expect(inserted.parent, isNull);
      expect(replacement.parentListIndex, 0);
      expect(changes, hasLength(1));
      _expectRootListAccessor(changes.single, 0);
      expect(changes.single.operation, isA<ListRemove>());
      final remove = changes.single.operation as ListRemove;
      expect(remove.removedValue, same(inserted));

      changes.clear();
      replacement.emitValueChange('updated replacement');

      expect(changes, hasLength(1));
      expect(changes.single.fieldAccessors, hasLength(3));
      expect(changes.single.fieldAccessors[0].fieldName, 'list');
      expect(changes.single.fieldAccessors[1].fieldType, FieldType.list);
      expect(changes.single.fieldAccessors[1].index, 0);
      expect(changes.single.fieldAccessors[2].fieldName, 'value');
      expect(changes.single.operation, isA<RawFieldUpdate>());
    });

    test('Range inserts and removes emit per-item operations', () {
      final first = TestModel('first');
      final second = TestModel('second');
      final root = TestRoot(
        list: AnthemObservableList<Object?>.of([first, second]),
      );
      final changes = <ModelChangeEvent>[];
      root.addRawFieldChangedListener(changes.add);

      final insertedA = TestModel('inserted A');
      final insertedB = TestModel('inserted B');
      root.list.insertAll(1, [insertedA, insertedB]);

      expect(insertedA.parent, same(root.list));
      expect(insertedA.parentListIndex, 1);
      expect(insertedB.parent, same(root.list));
      expect(insertedB.parentListIndex, 2);
      expect(second.parentListIndex, 3);
      expect(changes, hasLength(2));
      _expectRootListAccessor(changes[0], 1);
      _expectRootListAccessor(changes[1], 2);
      expect(changes[0].operation, isA<ListInsert>());
      expect((changes[0].operation as ListInsert).value, same(insertedA));
      expect(changes[1].operation, isA<ListInsert>());
      expect((changes[1].operation as ListInsert).value, same(insertedB));

      changes.clear();
      root.list.removeRange(1, 3);

      expect(insertedA.parent, isNull);
      expect(insertedB.parent, isNull);
      expect(first.parentListIndex, 0);
      expect(second.parentListIndex, 1);
      expect(changes, hasLength(2));
      _expectRootListAccessor(changes[0], 1);
      _expectRootListAccessor(changes[1], 1);
      expect(changes[0].operation, isA<ListRemove>());
      expect(
        (changes[0].operation as ListRemove).removedValue,
        same(insertedA),
      );
      expect(changes[1].operation, isA<ListRemove>());
      expect(
        (changes[1].operation as ListRemove).removedValue,
        same(insertedB),
      );

      changes.clear();
      second.emitValueChange('updated second');

      expect(changes, hasLength(1));
      expect(changes.single.fieldAccessors[1].index, 1);
    });

    test('Range replacements emit removes before inserts', () {
      final oldA = TestModel('old A');
      final oldB = TestModel('old B');
      final tail = TestModel('tail');
      final root = TestRoot(
        list: AnthemObservableList<Object?>.of([oldA, oldB, tail]),
      );
      final changes = <ModelChangeEvent>[];
      root.addRawFieldChangedListener(changes.add);

      final newA = TestModel('new A');
      final newB = TestModel('new B');
      final newC = TestModel('new C');
      root.list.replaceRange(0, 2, [newA, newB, newC]);

      expect(oldA.parent, isNull);
      expect(oldB.parent, isNull);
      expect(newA.parentListIndex, 0);
      expect(newB.parentListIndex, 1);
      expect(newC.parentListIndex, 2);
      expect(tail.parentListIndex, 3);

      expect(changes, hasLength(5));
      for (final change in changes.take(2)) {
        _expectRootListAccessor(change, 0);
        expect(change.operation, isA<ListRemove>());
      }
      expect((changes[0].operation as ListRemove).removedValue, same(oldA));
      expect((changes[1].operation as ListRemove).removedValue, same(oldB));

      for (var i = 2; i < changes.length; i++) {
        _expectRootListAccessor(changes[i], i - 2);
        expect(changes[i].operation, isA<ListInsert>());
      }
      expect((changes[2].operation as ListInsert).value, same(newA));
      expect((changes[3].operation as ListInsert).value, same(newB));
      expect((changes[4].operation as ListInsert).value, same(newC));
    });

    test('Clear and addAll replacement keeps nested list updates attached', () {
      final oldPort = TestModel(
        'old port',
        childList: AnthemObservableList<Object?>.of([18, 19]),
      );
      final root = TestRoot(list: AnthemObservableList<Object?>.of([oldPort]));
      final changes = <ModelChangeEvent>[];
      root.addRawFieldChangedListener(changes.add);

      final replacementPort = TestModel(
        'replacement port',
        childList: AnthemObservableList<Object?>.of([18, 19]),
      );

      root.list.clear();
      root.list.addAll([replacementPort]);

      expect(oldPort.parent, isNull);
      expect(replacementPort.parent, same(root.list));
      expect(replacementPort.parentListIndex, 0);
      expect(replacementPort.childList!.parent, same(replacementPort));
      expect(replacementPort.childList!.parentFieldName, 'childList');

      expect(changes, hasLength(2));
      _expectRootListAccessor(changes[0], 0);
      expect(changes[0].operation, isA<ListRemove>());
      expect((changes[0].operation as ListRemove).removedValue, same(oldPort));

      _expectRootListAccessor(changes[1], 0);
      expect(changes[1].operation, isA<ListInsert>());
      expect((changes[1].operation as ListInsert).value, same(replacementPort));

      changes.clear();
      replacementPort.childList!.removeAt(0);
      replacementPort.childList!.add(22);

      expect(changes, hasLength(2));
      expect(changes[0].fieldAccessors, hasLength(4));
      expect(changes[0].fieldAccessors[0].fieldName, 'list');
      expect(changes[0].fieldAccessors[1].fieldType, FieldType.list);
      expect(changes[0].fieldAccessors[1].index, 0);
      expect(changes[0].fieldAccessors[2].fieldName, 'childList');
      expect(changes[0].fieldAccessors[3].fieldType, FieldType.list);
      expect(changes[0].fieldAccessors[3].index, 0);
      expect(changes[0].operation, isA<ListRemove>());
      expect((changes[0].operation as ListRemove).removedValue, 18);

      expect(changes[1].fieldAccessors, hasLength(4));
      expect(changes[1].fieldAccessors[0].fieldName, 'list');
      expect(changes[1].fieldAccessors[1].fieldType, FieldType.list);
      expect(changes[1].fieldAccessors[1].index, 0);
      expect(changes[1].fieldAccessors[2].fieldName, 'childList');
      expect(changes[1].fieldAccessors[3].fieldType, FieldType.list);
      expect(changes[1].fieldAccessors[3].index, 1);
      expect(changes[1].operation, isA<ListInsert>());
      expect((changes[1].operation as ListInsert).value, 22);
    });
  });

  group('AnthemObservableMap serialization', () {
    test('Serializes supported keys and values recursively', () {
      final map = AnthemObservableMap<Object?, Object?>.of({
        TestEnum.first: TestModel('enum key value'),
        'list': AnthemObservableList<Object?>.of([
          TestModel('nested list model'),
        ]),
        'map': AnthemObservableMap<Object?, Object?>.of({
          TestEnum.second: TestModel('nested map model'),
        }),
        null: TestEnum.second,
      });

      expect(map.toJson(), {
        'first': _serializedModel(
          'enum key value',
          forEngine: false,
          forProjectFile: true,
        ),
        'list': [
          _serializedModel(
            'nested list model',
            forEngine: false,
            forProjectFile: true,
          ),
        ],
        'map': {
          'second': _serializedModel(
            'nested map model',
            forEngine: false,
            forProjectFile: true,
          ),
        },
        null: 'second',
      });

      expect(map.toJson(forEngine: true, forProjectFile: false), {
        'first': _serializedModel(
          'enum key value',
          forEngine: true,
          forProjectFile: false,
        ),
        'list': [
          _serializedModel(
            'nested list model',
            forEngine: true,
            forProjectFile: false,
          ),
        ],
        'map': {
          'second': _serializedModel(
            'nested map model',
            forEngine: true,
            forProjectFile: false,
          ),
        },
        null: 'second',
      });
    });

    test('Throws for unsupported keys and values', () {
      expect(
        () => AnthemObservableMap<Object?, Object?>.of({
          'unsupported': Object(),
        }).toJson(),
        throwsArgumentError,
      );
      expect(
        () => AnthemObservableMap<Object?, Object?>.of({
          Object(): 'unsupported',
        }).toJson(),
        throwsArgumentError,
      );
    });
  });

  group('AnthemObservableMap change events', () {
    test('Attaches children when a detached map is attached to a parent', () {
      final child = TestModel('child');
      final map = AnthemObservableMap<Object?, Object?>.of({'child': child});

      expect(child.parent, isNull);

      final root = TestRoot(map: map);

      expect(map.parent, same(root));
      expect(child.parent, same(map));
      expect(child.parentFieldType, FieldType.map);
      expect(child.parentMapKey, 'child');
      expect(child.setParentPropertiesOnChildrenCallCount, 1);
    });

    test('Put, update, and remove emit operations and maintain metadata', () {
      final root = TestRoot();
      final changes = <ModelChangeEvent>[];
      root.addRawFieldChangedListener(changes.add);

      final first = TestModel('first');
      root.map['one'] = first;

      expect(first.parent, same(root.map));
      expect(first.parentFieldType, FieldType.map);
      expect(first.parentMapKey, 'one');
      expect(changes, hasLength(1));
      _expectRootMapAccessor(changes.single, 'one');
      expect(changes.single.operation, isA<MapPut>());
      var put = changes.single.operation as MapPut;
      expect(put.oldValue, isNull);
      expect(put.newValue, same(first));
      expect(
        put.newValueSerialized,
        _serializedModel('first', forEngine: true, forProjectFile: false),
      );

      changes.clear();
      final replacement = TestModel('replacement');
      root.map['one'] = replacement;

      expect(first.parent, isNull);
      expect(replacement.parent, same(root.map));
      expect(replacement.parentMapKey, 'one');
      expect(changes, hasLength(1));
      _expectRootMapAccessor(changes.single, 'one');
      expect(changes.single.operation, isA<MapPut>());
      put = changes.single.operation as MapPut;
      expect(put.oldValue, same(first));
      expect(put.newValue, same(replacement));
      expect(
        put.newValueSerialized,
        _serializedModel('replacement', forEngine: true, forProjectFile: false),
      );

      changes.clear();
      replacement.emitValueChange('updated replacement');

      expect(changes, hasLength(1));
      expect(changes.single.fieldAccessors, hasLength(3));
      expect(changes.single.fieldAccessors[0].fieldName, 'map');
      expect(changes.single.fieldAccessors[1].fieldType, FieldType.map);
      expect(changes.single.fieldAccessors[1].key, 'one');
      expect(changes.single.fieldAccessors[2].fieldName, 'value');
      expect(changes.single.operation, isA<RawFieldUpdate>());

      changes.clear();
      root.map.remove('one');

      expect(replacement.parent, isNull);
      expect(changes, hasLength(1));
      _expectRootMapAccessor(changes.single, 'one');
      expect(changes.single.operation, isA<MapRemove>());
      final remove = changes.single.operation as MapRemove;
      expect(remove.removedValue, same(replacement));
    });

    test('Primitive puts and missing removes report the expected changes', () {
      final root = TestRoot();
      final changes = <ModelChangeEvent>[];
      root.addRawFieldChangedListener(changes.add);

      root.map[TestEnum.first] = 1;

      expect(changes, hasLength(1));
      _expectRootMapAccessor(changes.single, TestEnum.first);
      expect(changes.single.operation, isA<MapPut>());
      final put = changes.single.operation as MapPut;
      expect(put.oldValue, isNull);
      expect(put.newValue, 1);
      expect(put.newValueSerialized, 1);

      changes.clear();
      root.map.remove('missing');

      expect(changes, isEmpty);
    });

    test('Clear emits remove operations and detaches model values', () {
      final first = TestModel('first');
      final second = TestModel('second');
      final root = TestRoot();
      final changes = <ModelChangeEvent>[];
      root.addRawFieldChangedListener(changes.add);

      root.map['first'] = first;
      root.map['second'] = second;
      changes.clear();

      root.map.clear();

      expect(first.parent, isNull);
      expect(second.parent, isNull);
      expect(changes, hasLength(2));
      _expectRootMapAccessor(changes[0], 'first');
      _expectRootMapAccessor(changes[1], 'second');
      expect(changes[0].operation, isA<MapRemove>());
      expect((changes[0].operation as MapRemove).removedValue, same(first));
      expect(changes[1].operation, isA<MapRemove>());
      expect((changes[1].operation as MapRemove).removedValue, same(second));
    });
  });
}
