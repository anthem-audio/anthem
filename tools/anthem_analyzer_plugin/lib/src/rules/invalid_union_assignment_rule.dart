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
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import 'union_helpers.dart';

class InvalidUnionAssignmentRule extends AnalysisRule {
  static const DiagnosticCode code = _UnionWarningCode(
    'invalid_union_assignment',
    "Type '{0}' can't be assigned to union field '{1}'. Allowed types: {2}.",
    correctionMessage: 'Assign an allowed type or update the @Union type list.',
    type: DiagnosticType.STATIC_WARNING,
  );

  InvalidUnionAssignmentRule()
    : super(
        name: 'invalid_union_assignment',
        description:
            'Disallow assigning values that are not listed in @Union type annotations.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addNamedExpression(this, visitor);
    registry.addAssignmentExpression(this, visitor);
    registry.addConstructorFieldInitializer(this, visitor);
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  final InvalidUnionAssignmentRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (shouldSkipGeneratedFile(context)) return;

    final operator = node.operator.type;
    if (operator != TokenType.EQ &&
        operator != TokenType.QUESTION_QUESTION_EQ) {
      return;
    }

    final unionInfo = _unionInfoForElement(node.writeElement);
    if (unionInfo == null) return;

    _reportIfInvalid(expression: node.rightHandSide, unionInfo: unionInfo);
  }

  @override
  void visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    if (shouldSkipGeneratedFile(context)) return;

    final unionInfo = _unionInfoForElement(node.fieldName.element);
    if (unionInfo == null) return;

    _reportIfInvalid(expression: node.expression, unionInfo: unionInfo);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    if (shouldSkipGeneratedFile(context)) return;

    final unionInfo = _unionInfoForFormalParameter(node.element);
    if (unionInfo == null) return;

    _reportIfInvalid(expression: node.expression, unionInfo: unionInfo);
  }

  _UnionFieldInfo? _unionInfoForElement(Element? element) {
    if (element is FieldElement) {
      return _unionInfoForField(element);
    }

    if (element is PropertyAccessorElement) {
      final variable = element.variable;
      if (variable is FieldElement) {
        return _unionInfoForField(variable);
      }
    }

    return null;
  }

  _UnionFieldInfo? _unionInfoForField(FieldElement? field) {
    if (field == null) return null;

    final unionAnnotation = findUnionAnnotation(field.metadata.annotations);
    if (unionAnnotation == null) return null;

    final allowedTypes = typesFromUnionAnnotation(unionAnnotation);
    if (allowedTypes.isEmpty) return null;

    return _UnionFieldInfo(
      fieldName: field.displayName,
      allowsNull: field.type.nullabilitySuffix == NullabilitySuffix.question,
      allowedTypes: allowedTypes,
    );
  }

  _UnionFieldInfo? _unionInfoForFormalParameter(
    FormalParameterElement? parameter,
  ) {
    if (parameter == null) return null;

    if (parameter is SuperFormalParameterElement) {
      return _unionInfoForFormalParameter(parameter.superConstructorParameter);
    }

    if (parameter is FieldFormalParameterElement) {
      return _unionInfoForField(parameter.field);
    }

    return null;
  }

  void _reportIfInvalid({
    required Expression expression,
    required _UnionFieldInfo unionInfo,
  }) {
    final expressionType = expression.staticType;
    if (expressionType == null) return;
    if (_isStaticallyUncheckable(expressionType)) return;

    if (unionInfo.allowsNull &&
        (expression is NullLiteral ||
            expressionType.getDisplayString() == 'Null')) {
      return;
    }

    for (final allowedType in unionInfo.allowedTypes) {
      if (context.typeSystem.isSubtypeOf(expressionType, allowedType)) {
        return;
      }
    }

    // If the assigned expression is a supertype of any allowed subtype, then
    // static analysis cannot prove this assignment is invalid.
    if (_couldBeAnyAllowedSubtype(expressionType, unionInfo.allowedTypes)) {
      return;
    }

    final assignedTypeDisplay = expressionType.getDisplayString();

    rule.reportAtNode(
      expression,
      arguments: [
        assignedTypeDisplay,
        unionInfo.fieldName,
        unionInfo.allowedTypesDisplay,
      ],
    );
  }

  bool _isStaticallyUncheckable(DartType type) {
    if (type is DynamicType || type is InvalidType || type is VoidType) {
      return true;
    }

    if (type is TypeParameterType) {
      return true;
    }

    return false;
  }

  bool _couldBeAnyAllowedSubtype(
    DartType expressionType,
    List<DartType> allowedTypes,
  ) {
    for (final allowedType in allowedTypes) {
      if (context.typeSystem.isSubtypeOf(allowedType, expressionType)) {
        return true;
      }
    }

    return false;
  }
}

final class _UnionFieldInfo {
  final String fieldName;
  final bool allowsNull;
  final List<DartType> allowedTypes;

  _UnionFieldInfo({
    required this.fieldName,
    required this.allowsNull,
    required this.allowedTypes,
  });

  String get allowedTypesDisplay =>
      allowedTypes.map((type) => type.getDisplayString()).join(', ');
}

final class _UnionWarningCode extends DiagnosticCode {
  @override
  final DiagnosticType type;

  const _UnionWarningCode(
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
