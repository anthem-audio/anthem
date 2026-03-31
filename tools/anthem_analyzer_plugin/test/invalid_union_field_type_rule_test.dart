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

// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:anthem_analyzer_plugin/src/rules/invalid_union_field_type_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(InvalidUnionFieldTypeRuleTest);
  });
}

@reflectiveTest
class InvalidUnionFieldTypeRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = InvalidUnionFieldTypeRule();

    final anthemCodegen = newPackage('anthem_codegen');
    anthemCodegen.addFile('lib/include.dart', r'''
class Union {
  final List<Type> types;
  const Union(this.types);
}
''');

    super.setUp();
  }

  void test_fieldDeclaration_invalidUnionType() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

abstract class Processor {}
class Allowed implements Processor {}

class Node {
  @Union([Allowed, String])
  Processor processor;

  Node(this.processor);
}
''';

    const fieldToken = 'processor;';

    await assertDiagnostics(content, [
      error(
        InvalidUnionFieldTypeRule.code,
        _offsetOf(content, fieldToken),
        'processor'.length,
      ),
    ]);
  }

  void test_fieldDeclaration_validBaseType() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

abstract class Processor {}
class AllowedOne implements Processor {}
class AllowedTwo implements Processor {}

class Node {
  @Union([AllowedOne, AllowedTwo])
  Processor processor;

  Node(this.processor);
}
''';

    await assertNoDiagnostics(content);
  }

  void test_fieldDeclaration_validObjectType() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

class Allowed {}
class AlsoAllowed {}

class Node {
  @Union([Allowed, AlsoAllowed])
  Object processor;

  Node(this.processor);
}
''';

    await assertNoDiagnostics(content);
  }
}

int _offsetOf(String content, String search) {
  final offset = content.indexOf(search);
  if (offset < 0) {
    throw StateError('Search string not found: $search');
  }
  return offset;
}
