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

import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:anthem_codegen/generators/util/writer.dart';
import 'package:anthem_codegen/generators/util/model_class_info.dart';

import 'shared.dart';

void writeModelSyncFnDeclaration(Writer writer) {
  writer.writeLine(
      'void handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex);');
}

String getModelSyncFn(ModelClassInfo context) {
  final writer = Writer();

  writer.writeLine(
      'void ${context.annotatedClass.name}::handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex) {');
  writer.incrementWhitespace();

  var isFirst = true;

  for (var MapEntry(key: fieldName, value: field) in context.fields.entries) {
    if (field.hideAnnotation?.cpp == true) {
      continue;
    }

    writer.writeLine(
        '${isFirst ? '' : 'else '}if (request.fieldAccesses[fieldAccessIndex]->fieldName == "$fieldName") {');
    writer.incrementWhitespace();

    writer.writeLine('if (request.updateKind == FieldUpdateKind::set) {');
    writer.incrementWhitespace();
    _writeUpdate(
      context: context,
      writer: writer,
      type: field.typeInfo,
      updateKind: _FieldUpdateKind.set,
      fieldAccessExpression: 'this->$fieldName',
    );
    writer.decrementWhitespace();
    writer
        .writeLine('} else if (request.updateKind == FieldUpdateKind::add) {');
    writer.incrementWhitespace();
    _writeUpdate(
      context: context,
      writer: writer,
      type: field.typeInfo,
      updateKind: _FieldUpdateKind.add,
      fieldAccessExpression: 'this->$fieldName',
    );
    writer.decrementWhitespace();
    writer.writeLine(
        '} else if (request.updateKind == FieldUpdateKind::remove) {');
    writer.incrementWhitespace();
    _writeUpdate(
      context: context,
      writer: writer,
      type: field.typeInfo,
      updateKind: _FieldUpdateKind.remove,
      fieldAccessExpression: 'this->$fieldName',
    );
    writer.decrementWhitespace();
    writer.writeLine('}');

    writer.decrementWhitespace();
    writer.writeLine('}');

    isFirst = false;
  }

  writer.decrementWhitespace();
  writer.writeLine('}');

  return writer.result;
}

void _writeInvalidAccessWarning({
  required Writer writer,
  required ModelType type,
  required ModelClassInfo context,
  required String fieldAccessExpression,
}) {
  writer.writeLine(
      'std::cout << "Invalid field access: \\"$fieldAccessExpression\\", on model \\"${context.annotatedClass.name}\\"" << std::endl;');
  writer.writeLine(
      'std::cout << "The accessor \\"$fieldAccessExpression\\" does not point to an Anthem model or collection of Anthem models, so the update could not be forwarded." << std::endl;');
  writer.writeLine(
      'std::cout << "\\"$fieldAccessExpression\\" is of type \\"${type.name}\\"." << std::endl;');
}

void _writeSerializedValueNullCheck({required Writer writer}) {
  writer.writeLine('if (!request.serializedValue.has_value()) {');
  writer.incrementWhitespace();
  writer.writeLine(
      'std::cout << "Serialized value is null, but shouldn\'t be in this context." << std::endl;');
  writer.writeLine('return;');
  writer.decrementWhitespace();
  writer.writeLine('}');
}

void _writeIndexCheckForPrimitive({
  required int fieldAccessIndexMod,
  required Writer writer,
  required ModelType type,
  required ModelClassInfo context,
  required String fieldAccessExpression,
}) {
  writer.writeLine(
      'if (request.fieldAccesses.size() > fieldAccessIndex + 1 + $fieldAccessIndexMod) {');
  writer.incrementWhitespace();
  _writeInvalidAccessWarning(
    writer: writer,
    type: type,
    context: context,
    fieldAccessExpression: fieldAccessExpression,
  );
  writer.writeLine('return;');
  writer.decrementWhitespace();
  writer.writeLine('}');
}

void _writeUpdateTypeInvalidError({
  required Writer writer,
  required ModelClassInfo context,
  required _FieldUpdateKind updateKind,
  required ModelType type,
  required String fieldAccessExpression,
}) {
  writer.writeLine(
      'std::cout << "Invalid update type for accessor \\"$fieldAccessExpression\\" on model \\"${context.annotatedClass.name}\\"" << std::endl;');
  writer.writeLine(
      'std::cout << "Update type \\"${updateKind.name}\\" is not valid for field \\"$fieldAccessExpression\\" of type ${type.toString()}." << std::endl;');
}

/// Writes a field update for the given field.
///
/// The [fieldAccessExpression] parameter specifies the target to be modified,
/// as a C++ expression, and the [type] parameter specifies the type of the
/// field being updated.
///
/// As an example, a call to this function might look like:
///
/// ```dart
/// writeUpdate(
///   type: IntModelType(),
///   updateKind: _FieldUpdateKind.set,
///   modificationTarget: 'this->myStringField',
/// );
/// ```
///
/// This might generate code like:
///
/// ```cpp
/// // (A few validation checks on the request)
/// this->myStringField = std::stoll(request.serializedValue.value());
/// ```
///
/// If the field is a custom model, then this will also generate code to
/// forward appropriate requests to the child model. If the field is instead
/// a collection, then this function will recursively call itself to
/// generate code to update the collection. For example, given a Map<String,
/// int>, the generated code might look like:
///
/// ```cpp
/// // (A few validation checks on the request)
/// if (request.fieldAccesses.size() == fieldAccessIndex + 1) {
///   // After generating up to this point, the function will call itself
///   // recursively like so:
///   // writeUpdate(
///   //   type: IntModelType(),
///   //   updateKind: _FieldUpdateKind.set,
///   //   modificationTarget: 'this->myMapField[request.fieldAccesses[fieldAccessIndex + 1]->serializedMapValue.value()]',
///   // );
/// }
/// // Etc...
/// ```
void _writeUpdate({
  required Writer writer,
  required ModelType type,
  required _FieldUpdateKind updateKind,
  required String fieldAccessExpression,
  required ModelClassInfo context,
  int fieldAccessIndexMod = 0,
}) {
  switch (type) {
    case StringModelType():
      if (updateKind != _FieldUpdateKind.set) {
        _writeUpdateTypeInvalidError(
          writer: writer,
          context: context,
          updateKind: updateKind,
          type: type,
          fieldAccessExpression: fieldAccessExpression,
        );
        return;
      }

      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      _writeSerializedValueNullCheck(writer: writer);

      final stringGetter =
          'request.serializedValue.value().substr(1, request.serializedValue.value().size() - 2)';

      if (type.isNullable) {
        writer.writeLine('if (request.serializedValue.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine('$fieldAccessExpression = std::nullopt;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            '$fieldAccessExpression = std::optional<std::string>($stringGetter);');
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine('$fieldAccessExpression = $stringGetter;');
      }

      break;
    case IntModelType():
      if (updateKind != _FieldUpdateKind.set) {
        _writeUpdateTypeInvalidError(
          writer: writer,
          context: context,
          updateKind: updateKind,
          type: type,
          fieldAccessExpression: fieldAccessExpression,
        );
        return;
      }

      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      _writeSerializedValueNullCheck(writer: writer);

      if (type.isNullable) {
        writer.writeLine('if (request.serializedValue.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine('$fieldAccessExpression = std::nullopt;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            '$fieldAccessExpression = std::optional<int64_t>(std::stoll(request.serializedValue.value()));');
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            '$fieldAccessExpression = std::stoll(request.serializedValue.value());');
      }
      break;
    case DoubleModelType() || NumModelType():
      if (updateKind != _FieldUpdateKind.set) {
        _writeUpdateTypeInvalidError(
          writer: writer,
          context: context,
          updateKind: updateKind,
          type: type,
          fieldAccessExpression: fieldAccessExpression,
        );
        return;
      }

      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      _writeSerializedValueNullCheck(writer: writer);

      if (type.isNullable) {
        writer.writeLine('if (request.serializedValue.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine('$fieldAccessExpression = std::nullopt;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            '$fieldAccessExpression = std::optional<double>(std::stod(request.serializedValue.value()));');
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            '$fieldAccessExpression = std::stod(request.serializedValue.value());');
      }
      break;
    case BoolModelType():
      if (updateKind != _FieldUpdateKind.set) {
        _writeUpdateTypeInvalidError(
          writer: writer,
          context: context,
          updateKind: updateKind,
          type: type,
          fieldAccessExpression: fieldAccessExpression,
        );
        return;
      }

      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      _writeSerializedValueNullCheck(writer: writer);

      if (type.isNullable) {
        writer.writeLine('if (request.serializedValue.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine('$fieldAccessExpression = std::nullopt;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            '$fieldAccessExpression = std::optional<bool>(request.serializedValue.value() == "true");');
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            '$fieldAccessExpression = request.serializedValue.value() == "true";');
      }
      break;
    case EnumModelType():
      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      break;
    case ColorModelType():
      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      break;
    case ListModelType():
      // TODO: Implement
      break;
    case MapModelType():
      writer.writeLine(
          'if (request.fieldAccesses.size() > fieldAccessIndex + 1) {');
      writer.incrementWhitespace();
      _writeUpdate(
        context: context,
        writer: writer,
        type: type.valueType,
        updateKind: updateKind,
        fieldAccessExpression:
            '$fieldAccessExpression[request.fieldAccesses[fieldAccessIndex + 1]->serializedMapValue.value()]', // TODO: deserialize the key!
        fieldAccessIndexMod: fieldAccessIndexMod + 1,
      );
      writer.decrementWhitespace();

      writer.writeLine('} else {');
      writer.incrementWhitespace();
      if (updateKind == _FieldUpdateKind.add) {
        _writeUpdateTypeInvalidError(
          writer: writer,
          context: context,
          updateKind: updateKind,
          type: type,
          fieldAccessExpression: fieldAccessExpression,
        );
        return;
      } else if (updateKind == _FieldUpdateKind.remove) {
        writer.writeLine('// TODO: remove');
      } else if (updateKind == _FieldUpdateKind.set) {
        writer.writeLine('// TODO: set');
      }
      writer.decrementWhitespace();
      writer.writeLine('}');
      break;
    case CustomModelType() || UnknownModelType():
      if (updateKind != _FieldUpdateKind.set) {
        _writeUpdateTypeInvalidError(
          writer: writer,
          context: context,
          updateKind: updateKind,
          type: type,
          fieldAccessExpression: fieldAccessExpression,
        );
        return;
      }

      // If this field is a custom model and this is the last accessor in the
      // chain, then we should deserialize the provided JSON into this field.
      writer.writeLine(
          'if (request.fieldAccesses.size() == fieldAccessIndex + 1 + $fieldAccessIndexMod) {');
      writer.incrementWhitespace();
      _writeSerializedValueNullCheck(writer: writer);
      writer.writeLine(
          'auto result = rfl::json::read<${getCppType(type)}>(request.serializedValue.value());');
      writer.writeLine('auto error = result.error();');

      writer.writeLine('if (error.has_value()) {');
      writer.incrementWhitespace();
      writer.writeLine(
          'std::cout << "Error deserializing to $fieldAccessExpression:" << std::endl << error.value().what() << std::endl;');
      writer.writeLine('return;');
      writer.decrementWhitespace();
      writer.writeLine('} else {');
      writer.incrementWhitespace();
      writer.writeLine('$fieldAccessExpression =  result.value();');
      writer.decrementWhitespace();
      writer.writeLine('}');

      writer.decrementWhitespace();

      // If this field is a custom model and this is not the last accessor in
      // the chain, then we should forward the update to the child.
      writer.writeLine('} else {');
      writer.incrementWhitespace();
      var nullable = '';
      if (type.isNullable) {
        writer.writeLine('if ($fieldAccessExpression.has_value()) {');
        writer.incrementWhitespace();
        nullable = '.value()';
      }
      writer.writeLine(
          '$fieldAccessExpression$nullable->handleModelUpdate(request, fieldAccessIndex + 1 + $fieldAccessIndexMod);');
      if (type.isNullable) {
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            'std::cout << "The value at accessor $fieldAccessExpression is null, so the update could not be forwarded." << std::endl;');
        writer.decrementWhitespace();
        writer.writeLine('}');
      }
      writer.decrementWhitespace();
      writer.writeLine('}');

      break;
  }
}

enum _FieldUpdateKind { set, add, remove }
