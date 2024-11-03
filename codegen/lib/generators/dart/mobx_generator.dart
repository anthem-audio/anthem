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

import '../util/model_class_info.dart';

/// Generates atoms for observable fields.
///
/// Note that this does not generate anything for sealed classes.
String generateMobXAtoms({required ModelClassInfo context}) {
  var result = '';

  for (final MapEntry(key: fieldName, value: fieldInfo)
      in context.fields.entries) {
    if (!fieldInfo.isObservable) continue;

    result += 'late final _\$${fieldName}Atom = \n';
    result +=
        "    Atom(name: '${context.baseClass.name}.$fieldName', context: context);\n";
  }

  return result;
}

String generateMobXGetter(String fieldName, ModelFieldInfo fieldInfo) {
  return '_\$${fieldName}Atom.reportRead();\n';
}

String wrapCodeWithMobXSetter(
    String fieldName, ModelFieldInfo fieldInfo, String code) {
  return '''_\$${fieldName}Atom.reportWrite(value, super.$fieldName, () {
  $code
});''';
}
