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

import 'package:shared_preferences/shared_preferences.dart';

/// A new instance per session keeps tests away from native user preferences.
/// Native plugins are still registered and initialized by normal app startup.
class MemoryPreferences implements SharedPreferencesAsync {
  final Map<String, Object> _values = {};

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async => {
    for (final entry in _values.entries)
      if (allowList == null || allowList.contains(entry.key))
        entry.key: entry.value is List<String>
            ? List<String>.from(entry.value as List<String>)
            : entry.value,
  };

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async =>
      (await getAll(allowList: allowList)).keys.toSet();
  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);
  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;
  @override
  Future<int?> getInt(String key) async => _values[key] as int?;
  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;
  @override
  Future<String?> getString(String key) async => _values[key] as String?;
  @override
  Future<List<String>?> getStringList(String key) async {
    final value = _values[key] as List<String>?;
    return value == null ? null : List<String>.from(value);
  }

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;
  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;
  @override
  Future<void> setDouble(String key, double value) async =>
      _values[key] = value;
  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = List<String>.from(value);
  @override
  Future<void> remove(String key) async => _values.remove(key);
  @override
  Future<void> clear({Set<String>? allowList}) async {
    if (allowList == null) {
      _values.clear();
    } else {
      _values.removeWhere((key, _) => allowList.contains(key));
    }
  }
}
