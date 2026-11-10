/*
  Copyright (C) 2024 - 2026 Joshua Wade

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
  var result = StringBuffer();

  for (final MapEntry(key: fieldName, value: fieldInfo)
      in context.fields.entries) {
    if (!fieldInfo.isObservable) continue;

    result.write('late final _\$${fieldName}Atom = \n');
    result.write(
      "    Atom(name: '${context.baseClass.name}.$fieldName', context: context);\n",
    );
  }

  return result.toString();
}

String generateMobXGetter(String fieldName, ModelFieldInfo fieldInfo) {
  return '''var blockObservation = false;

if (isBlockObservationBuilderActive) {
  var model = this as AnthemModelBase?;
  while (model != null) {
    if (model.blockDescendantObservations) {
      blockObservation = true;
      break;
    }
    model = model.parent;
  }
}

if (!blockObservation) {
  _\$${fieldName}Atom.reportRead();
}
''';
}

String wrapCodeWithMobXSetter(
  String fieldName,
  ModelFieldInfo fieldInfo,
  String code,
) {
  if (fieldInfo.fieldElement.isFinal) {
    // The backing assignment already succeeded. Even null initializes the field.
    return '''_\$${fieldName}Atom.reportWrite(\$value, null, () {
  $code
}, equals: (_, _) => false);''';
  }

  String valueSetter;

  // A late field may still be unset when its old value is read.
  if (fieldInfo.fieldElement.isLate) {
    valueSetter =
        '''try {
  \$oldValue = $fieldName;
} catch (_) {
  \$oldValue = null;
}''';
  } else {
    valueSetter = '\$oldValue = $fieldName;';
  }

  return '''${fieldInfo.typeInfo.dartName}? \$oldValue;
$valueSetter
_\$${fieldName}Atom.reportWrite(\$value, \$oldValue, () {
  $code
});''';
}
