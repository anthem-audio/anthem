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
import 'package:anthem_analyzer_plugin/src/rules/invalid_union_assignment_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(InvalidUnionAssignmentRuleTest);
  });
}

@reflectiveTest
class InvalidUnionAssignmentRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = InvalidUnionAssignmentRule();

    final anthemCodegen = newPackage('anthem_codegen');
    anthemCodegen.addFile('lib/include.dart', r'''
class Union {
  final List<Type> types;
  const Union(this.types);
}
''');

    super.setUp();
  }

  void test_assignment_invalidType() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

class Allowed {}
class NotAllowed {}

class Node {
  @Union([Allowed])
  Object processor;

  Node(this.processor);
}

void f(Node node) {
  node.processor = NotAllowed();
}
''';

    const expression = 'NotAllowed()';

    await assertDiagnostics(content, [
      error(
        InvalidUnionAssignmentRule.code,
        _offsetOf(content, expression),
        expression.length,
      ),
    ]);
  }

  void test_constructorFieldInitializer_invalidType() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

class Allowed {}
class NotAllowed {}

class Node {
  @Union([Allowed])
  Object processor;

  Node() : processor = NotAllowed();
}
''';

    const expression = 'NotAllowed()';

    await assertDiagnostics(content, [
      error(
        InvalidUnionAssignmentRule.code,
        _offsetOf(content, expression),
        expression.length,
      ),
    ]);
  }

  void test_namedArgument_invalidType() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

class Allowed {}
class NotAllowed {}

class Node {
  @Union([Allowed])
  Object processor;

  Node({required this.processor});
}

void f() {
  Node(processor: NotAllowed());
}
''';

    const expression = 'NotAllowed()';

    await assertDiagnostics(content, [
      error(
        InvalidUnionAssignmentRule.code,
        _offsetOf(content, expression),
        expression.length,
      ),
    ]);
  }

  void test_namedArgument_superParameter_invalidType() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

class Allowed {}
class NotAllowed {}

class BaseNode {
  @Union([Allowed])
  Object processor;

  BaseNode({required this.processor});
}

class ChildNode extends BaseNode {
  ChildNode({required super.processor});
}

void f() {
  ChildNode(processor: NotAllowed());
}
''';

    const expression = 'NotAllowed()';

    await assertDiagnostics(content, [
      error(
        InvalidUnionAssignmentRule.code,
        _offsetOf(content, expression),
        expression.length,
      ),
    ]);
  }

  void test_namedArgument_nullableUnion_allowsNull() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

class Allowed {}

class Node {
  @Union([Allowed])
  Object? processor;

  Node({required this.processor});
}

void f() {
  Node(processor: null);
}
''';

    await assertNoDiagnostics(content);
  }

  void test_namedArgument_validType() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

class Allowed {}

class Node {
  @Union([Allowed])
  Object processor;

  Node({required this.processor});
}

void f() {
  Node(processor: Allowed());
}
''';

    await assertNoDiagnostics(content);
  }

  void test_assignment_invalidConcreteSubtype_onBaseTypedField() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

abstract class Processor {}
class Allowed implements Processor {}
class NotAllowed implements Processor {}

class Node {
  @Union([Allowed])
  Processor processor;

  Node(this.processor);
}

void f(Node node) {
  node.processor = NotAllowed();
}
''';

    const expression = 'NotAllowed()';

    await assertDiagnostics(content, [
      error(
        InvalidUnionAssignmentRule.code,
        _offsetOf(content, expression),
        expression.length,
      ),
    ]);
  }

  void test_assignment_supertypeExpression_skipsDiagnostic() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

abstract class Processor {}
class Allowed implements Processor {}

class Node {
  @Union([Allowed])
  Processor processor;

  Node(this.processor);
}

void f(Node node, Processor value) {
  node.processor = value;
}
''';

    await assertNoDiagnostics(content);
  }

  void test_namedArgument_supertypeExpression_skipsDiagnostic() async {
    final content = r'''
import 'package:anthem_codegen/include.dart';

abstract class Processor {}
class Allowed implements Processor {}

class Node {
  @Union([Allowed])
  Processor processor;

  Node({required this.processor});
}

void f(Processor value) {
  Node(processor: value);
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
