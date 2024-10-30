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

import 'package:anthem_codegen/include/serialize_value.dart';
import 'package:mobx/mobx.dart';

import 'package:anthem_codegen/include.dart';

class AnthemObservableList<T> extends ObservableList<T> with AnthemModelBase {
  @override
  AnthemObservableList({super.context, super.name}) : super() {
    _init();
  }

  @override
  AnthemObservableList.of(super.elements, {super.context, super.name})
      : super.of() {
    _init();
  }

  void _init() {
    if (T is AnthemModelBase) {
      for (var i = 0; i < length; i++) {
        _setParamsOnIndex(i);
      }
    }

    observe((change) {
      int? firstChangedIndex;

      if (change.elementChanges != null) {
        for (final elementChange in change.elementChanges!) {
          if (elementChange.type == OperationType.add) {
            firstChangedIndex = elementChange.index;

            notifyFieldChanged(
              operation: ListInsert(
                index: elementChange.index,
                value: serializeValue(elementChange.newValue,
                    includeFieldsForEngine: true),
              ),
              accessorChain: [
                FieldAccessor(
                  fieldType: FieldType.list,
                  index: elementChange.index,
                ),
              ],
            );
          }
        }
      }

      if (firstChangedIndex != null) {
        for (var i = firstChangedIndex; i < length; i++) {
          _setParamsOnIndex(i);
        }
      }
    });
  }

  void _setParamsOnIndex(int index) {
    final element = elementAt(index) as AnthemModelBase;

    element.setParentProperties(
      parent: this,
      fieldType: FieldType.list,
      index: index,
    );
  }

  @override
  List<Object?> toJson({bool includeFieldsForEngine = false}) {
    return map(
      (e) => serializeValue(e, includeFieldsForEngine: includeFieldsForEngine),
    ).toList();
  }
}

class AnthemObservableMap<K, V> extends ObservableMap<K, V>
    with AnthemModelBase {
  AnthemObservableMap({super.context, super.name}) : super() {
    _init();
  }

  AnthemObservableMap.of(super.entries, {super.context, super.name})
      : super.of() {
    _init();
  }

  void _init() {
    if (V is AnthemModelBase) {
      for (final key in keys) {
        _setParamsOnValue(key);
      }
    }

    observe((change) {
      if (change.type == OperationType.add ||
          change.type == OperationType.update) {
        final key = change.key as K;

        notifyFieldChanged(
          operation: MapPut(
              value: serializeValue(this[key], includeFieldsForEngine: true)),
          accessorChain: [
            FieldAccessor(
              fieldType: FieldType.map,
              key: key,
            ),
          ],
        );
      }
    });
  }

  void _setParamsOnValue(K key) {
    final model = this[key] as AnthemModelBase;

    model.setParentProperties(
      parent: this,
      fieldType: FieldType.map,
      key: key,
    );
  }

  @override
  Map<Object?, Object?> toJson({bool includeFieldsForEngine = false}) {
    return map(
      (key, value) => MapEntry(
        serializeValue(key, includeFieldsForEngine: includeFieldsForEngine),
        serializeValue(value, includeFieldsForEngine: includeFieldsForEngine),
      ),
    );
  }
}
