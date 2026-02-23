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

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'union_helpers.dart';

class InvalidUnionFieldTypeRule extends AnalysisRule {
  static const DiagnosticCode code = _UnionFieldTypeWarningCode(
    'invalid_union_field_type',
    "Union type '{0}' isn't assignable to field '{1}' with declared type '{2}'.",
    correctionMessage:
        'Make the field type a supertype of all @Union entries or update the @Union list.',
    type: DiagnosticType.STATIC_WARNING,
  );

  InvalidUnionFieldTypeRule()
    : super(
        name: 'invalid_union_field_type',
        description:
            'Disallow @Union declarations where listed types are incompatible with the declared field type.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addFieldDeclaration(this, visitor);
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  final InvalidUnionFieldTypeRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (shouldSkipGeneratedFile(context)) return;

    for (final variable in node.fields.variables) {
      final field = variable.declaredFragment?.element;
      if (field == null) continue;

      final unionAnnotation = findUnionAnnotation(field.metadata.annotations);
      if (unionAnnotation == null) continue;

      final allowedTypes = typesFromUnionAnnotation(unionAnnotation);
      if (allowedTypes.isEmpty) continue;

      for (final allowedType in allowedTypes) {
        if (context.typeSystem.isSubtypeOf(allowedType, field.type)) {
          continue;
        }

        rule.reportAtNode(
          variable,
          arguments: [
            allowedType.getDisplayString(),
            field.displayName,
            field.type.getDisplayString(),
          ],
        );
      }
    }
  }
}

final class _UnionFieldTypeWarningCode extends DiagnosticCode {
  @override
  final DiagnosticType type;

  const _UnionFieldTypeWarningCode(
    String name,
    String problemMessage, {
    required this.type,
    super.correctionMessage,
  }) : super(
         name: name,
         problemMessage: problemMessage,
         uniqueName: 'AnthemAnalyzer.$name',
       );

  @override
  DiagnosticSeverity get severity => type.severity;
}
