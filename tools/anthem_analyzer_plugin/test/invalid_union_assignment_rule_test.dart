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
}

int _offsetOf(String content, String search) {
  final offset = content.indexOf(search);
  if (offset < 0) {
    throw StateError('Search string not found: $search');
  }
  return offset;
}
