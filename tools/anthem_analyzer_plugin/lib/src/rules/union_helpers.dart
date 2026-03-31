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

import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

ElementAnnotation? findUnionAnnotation(
  Iterable<ElementAnnotation> annotations,
) {
  for (final annotation in annotations) {
    final annotationElement = annotation.element;
    if (annotationElement is! ConstructorElement) continue;

    final enclosingElement = annotationElement.enclosingElement;
    if (enclosingElement is! ClassElement) continue;

    if (enclosingElement.name == 'Union') {
      return annotation;
    }
  }

  return null;
}

List<DartType> typesFromUnionAnnotation(ElementAnnotation annotation) {
  final constantValue = annotation.computeConstantValue();
  final typeList = constantValue?.getField('types')?.toListValue();
  if (typeList == null) return const [];

  return [
    for (final item in typeList)
      if (item.toTypeValue() case final DartType type) type,
  ];
}

bool shouldSkipGeneratedFile(RuleContext context) {
  final path = context.currentUnit?.file.path;
  if (path == null) return false;

  return path.endsWith('.g.dart') || path.endsWith('.g.part');
}
