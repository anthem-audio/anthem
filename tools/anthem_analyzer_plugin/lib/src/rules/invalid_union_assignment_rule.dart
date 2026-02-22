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
    if (_shouldSkipFile()) return;

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
    if (_shouldSkipFile()) return;

    final unionInfo = _unionInfoForElement(node.fieldName.element);
    if (unionInfo == null) return;

    _reportIfInvalid(expression: node.expression, unionInfo: unionInfo);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    if (_shouldSkipFile()) return;

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

    final unionAnnotation = _findUnionAnnotation(field.metadata.annotations);
    if (unionAnnotation == null) return null;

    final allowedTypes = _typesFromUnionAnnotation(unionAnnotation);
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

    final display = type.getDisplayString();
    return display == 'Object' || display == 'Object?';
  }

  bool _shouldSkipFile() {
    final path = context.currentUnit?.file.path;
    if (path == null) return false;

    return path.endsWith('.g.dart') || path.endsWith('.g.part');
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

ElementAnnotation? _findUnionAnnotation(
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

List<DartType> _typesFromUnionAnnotation(ElementAnnotation annotation) {
  final constantValue = annotation.computeConstantValue();
  final typeList = constantValue?.getField('types')?.toListValue();
  if (typeList == null) return const [];

  return [
    for (final item in typeList)
      if (item.toTypeValue() case final DartType type) type,
  ];
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
