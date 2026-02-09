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

part 'model_sync_lifecycle_test.g.dart';

@AnthemModel(serializable: true, generateModelSync: true)
class LeafModel extends _LeafModel
    with _$LeafModel, _$LeafModelAnthemModelMixin {
  LeafModel({required super.id, required super.value});
  LeafModel.uninitialized() : super(id: 0, value: '');

  factory LeafModel.fromJson(Map<String, dynamic> json) =>
      _$LeafModelAnthemModelMixin.fromJson(json);
}

abstract class _LeafModel with Store, AnthemModelBase {
  late int id;
  String? value;

  _LeafModel({required this.id, required this.value});
}

@AnthemModel(serializable: true, generateModelSync: true)
class BranchModel extends _BranchModel
    with _$BranchModel, _$BranchModelAnthemModelMixin {
  BranchModel({required super.id, super.child});
  BranchModel.uninitialized() : super(id: 0);

  factory BranchModel.fromJson(Map<String, dynamic> json) =>
      _$BranchModelAnthemModelMixin.fromJson(json);
}

abstract class _BranchModel with Store, AnthemModelBase {
  late int id;
  LeafModel? child;

  AnthemObservableList<LeafModel> leafList = AnthemObservableList();
  AnthemObservableMap<String, LeafModel> leafMap = AnthemObservableMap();

  _BranchModel({required this.id, this.child});
}

@AnthemModel(serializable: true, generateModelSync: true)
class RootModel extends _RootModel
    with _$RootModel, _$RootModelAnthemModelMixin {
  RootModel({required super.id, super.branch}) {
    _init();
  }
  RootModel.uninitialized() : super(id: 0) {
    _init();
  }

  void _init() {
    isTopLevelModel = true;
    setParentPropertiesOnChildren();
  }

  factory RootModel.fromJson(Map<String, dynamic> json) =>
      _$RootModelAnthemModelMixin.fromJson(json);
}

abstract class _RootModel with Store, AnthemModelBase {
  late int id;
  BranchModel? branch;

  AnthemObservableList<LeafModel> leaves = AnthemObservableList();
  AnthemObservableMap<String, LeafModel> leafMap = AnthemObservableMap();

  _RootModel({required this.id, this.branch});
}

typedef CapturedChange = ({
  List<FieldAccessor> accessors,
  FieldOperation operation,
});

void main() {
  group('Model sync lifecycle', () {
    late RootModel root;
    late List<CapturedChange> changes;

    setUp(() {
      root = RootModel(id: 1);
      changes = [];

      root.addRawFieldChangedListener((accessors, operation) {
        changes.add((
          accessors: List<FieldAccessor>.from(accessors),
          operation: operation,
        ));
      });
    });

    test('Raw field replacement detaches old child and attaches new child', () {
      final oldLeaf = LeafModel(id: 10, value: 'old');
      final newLeaf = LeafModel(id: 11, value: 'new');

      root.branch = BranchModel(id: 5, child: oldLeaf);
      changes.clear();

      root.branch!.child = newLeaf;

      expect(oldLeaf.parent, isNull);
      expect(newLeaf.parent, same(root.branch));
      expect(newLeaf.parentFieldType, FieldType.raw);
      expect(newLeaf.parentFieldName, 'child');

      expect(changes, hasLength(1));
      final change = changes.single;
      expect(change.accessors, hasLength(2));
      expect(change.accessors[0].fieldName, 'branch');
      expect(change.accessors[1].fieldName, 'child');
      expect(change.operation, isA<RawFieldUpdate>());
      final operation = change.operation as RawFieldUpdate;
      expect(operation.oldValue, same(oldLeaf));
      expect(operation.newValue, same(newLeaf));
    });

    test('List remove detaches removed child', () {
      final leaf = LeafModel(id: 10, value: 'item');

      root.leaves.add(leaf);
      changes.clear();

      root.leaves.removeAt(0);

      expect(leaf.parent, isNull);

      expect(changes, hasLength(1));
      final change = changes.single;
      expect(change.accessors, hasLength(2));
      expect(change.accessors[0].fieldName, 'leaves');
      expect(change.accessors[1].fieldType, FieldType.list);
      expect(change.accessors[1].index, 0);
      expect(change.operation, isA<ListRemove>());
      final operation = change.operation as ListRemove;
      expect(operation.removedValue, same(leaf));
    });

    test('List update detaches old child and attaches new child', () {
      final oldLeaf = LeafModel(id: 10, value: 'old');
      final newLeaf = LeafModel(id: 11, value: 'new');

      root.leaves.add(oldLeaf);
      changes.clear();

      root.leaves[0] = newLeaf;

      expect(oldLeaf.parent, isNull);
      expect(newLeaf.parent, same(root.leaves));
      expect(newLeaf.parentFieldType, FieldType.list);
      expect(newLeaf.parentListIndex, 0);

      expect(changes, hasLength(1));
      final change = changes.single;
      expect(change.operation, isA<ListUpdate>());
      final operation = change.operation as ListUpdate;
      expect(operation.oldValue, same(oldLeaf));
      expect(operation.newValue, same(newLeaf));
    });

    test('List insert rebinds shifted indices for descendant updates', () {
      final first = LeafModel(id: 10, value: 'first');
      final second = LeafModel(id: 11, value: 'second');

      root.leaves.add(first);
      root.leaves.add(second);
      changes.clear();

      root.leaves.insert(0, LeafModel(id: 12, value: 'inserted'));
      changes.clear();

      first.value = 'first updated';

      expect(first.parentListIndex, 1);
      expect(changes, hasLength(1));

      final change = changes.single;
      expect(change.accessors, hasLength(3));
      expect(change.accessors[0].fieldName, 'leaves');
      expect(change.accessors[1].fieldType, FieldType.list);
      expect(change.accessors[1].index, 1);
      expect(change.accessors[2].fieldName, 'value');
    });

    test('List remove rebinds shifted indices for descendant updates', () {
      final first = LeafModel(id: 10, value: 'first');
      final second = LeafModel(id: 11, value: 'second');
      final third = LeafModel(id: 12, value: 'third');

      root.leaves.add(first);
      root.leaves.add(second);
      root.leaves.add(third);
      changes.clear();

      root.leaves.removeAt(0);
      changes.clear();

      second.value = 'second updated';

      expect(second.parentListIndex, 0);
      expect(changes, hasLength(1));

      final change = changes.single;
      expect(change.accessors, hasLength(3));
      expect(change.accessors[0].fieldName, 'leaves');
      expect(change.accessors[1].fieldType, FieldType.list);
      expect(change.accessors[1].index, 0);
      expect(change.accessors[2].fieldName, 'value');
    });

    test('Map remove detaches removed child', () {
      final leaf = LeafModel(id: 10, value: 'item');

      root.leafMap['key'] = leaf;
      changes.clear();

      root.leafMap.remove('key');

      expect(leaf.parent, isNull);

      expect(changes, hasLength(1));
      final change = changes.single;
      expect(change.accessors, hasLength(2));
      expect(change.accessors[0].fieldName, 'leafMap');
      expect(change.accessors[1].fieldType, FieldType.map);
      expect(change.accessors[1].key, 'key');
      expect(change.operation, isA<MapRemove>());
      final operation = change.operation as MapRemove;
      expect(operation.removedValue, same(leaf));
    });

    test(
      'Map put on existing key detaches old child and attaches new child',
      () {
        final oldLeaf = LeafModel(id: 10, value: 'old');
        final newLeaf = LeafModel(id: 11, value: 'new');

        root.leafMap['key'] = oldLeaf;
        changes.clear();

        root.leafMap['key'] = newLeaf;

        expect(oldLeaf.parent, isNull);
        expect(newLeaf.parent, same(root.leafMap));
        expect(newLeaf.parentFieldType, FieldType.map);
        expect(newLeaf.parentMapKey, 'key');

        expect(changes, hasLength(1));
        final change = changes.single;
        expect(change.operation, isA<MapPut>());
        final operation = change.operation as MapPut;
        expect(operation.oldValue, same(oldLeaf));
        expect(operation.newValue, same(newLeaf));
      },
    );

    test('Detached children no longer propagate changes', () {
      final leaf = LeafModel(id: 10, value: 'item');

      root.leaves.add(leaf);
      root.leaves.removeAt(0);
      changes.clear();

      leaf.value = 'detached update';

      expect(changes, isEmpty);
    });

    test('Reattached children propagate changes to their new parent path', () {
      final leaf = LeafModel(id: 10, value: 'item');

      root.leaves.add(leaf);
      root.leaves.removeAt(0);
      root.leafMap['reattached'] = leaf;
      changes.clear();

      leaf.value = 'reattached update';

      expect(changes, hasLength(1));
      final change = changes.single;
      expect(change.accessors, hasLength(3));
      expect(change.accessors[0].fieldName, 'leafMap');
      expect(change.accessors[1].fieldType, FieldType.map);
      expect(change.accessors[1].key, 'reattached');
      expect(change.accessors[2].fieldName, 'value');
    });

    test(
      'Constructor-provided nested children attach during top-level init',
      () {
        final child = LeafModel(id: 10, value: 'child');
        final branch = BranchModel(id: 5, child: child);

        final localRoot = RootModel(id: 2, branch: branch);

        expect(branch.parent, same(localRoot));
        expect(branch.parentFieldName, 'branch');
        expect(child.parent, same(branch));
        expect(child.parentFieldName, 'child');

        final localChanges = <CapturedChange>[];
        localRoot.addRawFieldChangedListener((accessors, operation) {
          localChanges.add((
            accessors: List<FieldAccessor>.from(accessors),
            operation: operation,
          ));
        });

        child.value = 'updated';

        expect(localChanges, hasLength(1));
        expect(localChanges.single.accessors.map((a) => a.fieldName), [
          'branch',
          'child',
          'value',
        ]);
      },
    );

    test('fromJson-attached children propagate lifecycle updates', () {
      final original = RootModel(
        id: 2,
        branch: BranchModel(id: 3, child: LeafModel(id: 4, value: 'child')),
      );
      original.leaves.add(LeafModel(id: 5, value: 'list'));
      original.leafMap['map'] = LeafModel(id: 6, value: 'map');

      final deserialized = RootModel.fromJson(original.toJson());

      final branch = deserialized.branch!;
      final child = branch.child!;
      final listLeaf = deserialized.leaves.first;
      final mapLeaf = deserialized.leafMap['map']!;

      expect(branch.parent, same(deserialized));
      expect(child.parent, same(branch));
      expect(listLeaf.parent, same(deserialized.leaves));
      expect(mapLeaf.parent, same(deserialized.leafMap));

      final localChanges = <CapturedChange>[];
      deserialized.addRawFieldChangedListener((accessors, operation) {
        localChanges.add((
          accessors: List<FieldAccessor>.from(accessors),
          operation: operation,
        ));
      });

      child.value = 'updated';

      expect(localChanges, hasLength(1));
      expect(localChanges.single.accessors.map((a) => a.fieldName), [
        'branch',
        'child',
        'value',
      ]);
    });

    test('onModelFirstAttached runs once and after first attachment', () async {
      final leaf = LeafModel(id: 10, value: 'item');
      var callbackCalls = 0;
      var callbackSawParent = false;

      leaf.onModelFirstAttached(() {
        callbackCalls++;
        callbackSawParent = leaf.parent != null;
      });

      expect(callbackCalls, 0);

      root.leaves.add(leaf);
      expect(callbackCalls, 0);

      await Future<void>.delayed(Duration.zero);

      expect(callbackCalls, 1);
      expect(callbackSawParent, isTrue);

      root.leaves.removeAt(0);
      root.leaves.add(leaf);
      await Future<void>.delayed(Duration.zero);

      expect(callbackCalls, 1);
    });

    test('onModelFirstAttached throws on already attached model', () {
      final leaf = LeafModel(id: 10, value: 'item');

      root.leaves.add(leaf);

      expect(
        () => leaf.onModelFirstAttached(() {}),
        throwsA(isA<StateError>()),
      );
    });

    test('getFirstAncestorOfType returns matching ancestors', () {
      final child = LeafModel(id: 10, value: 'child');
      root.branch = BranchModel(id: 5, child: child);

      expect(child.getFirstAncestorOfType<BranchModel>(), same(root.branch));
      expect(child.getFirstAncestorOfType<RootModel>(), same(root));
    });

    test('getFirstAncestorOfType throws when no ancestor is found', () {
      final detached = LeafModel(id: 10, value: 'detached');

      expect(
        () => detached.getFirstAncestorOfType<RootModel>(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
