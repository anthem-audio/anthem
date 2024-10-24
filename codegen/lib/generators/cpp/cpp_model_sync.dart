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

    void writeInvalidAccessWarning() {
      writer.writeLine(
          'std::cout << "Invalid field access: \\"$fieldName\\", on model \\"${context.annotatedClass.name}\\"" << std::endl;');
      writer.writeLine(
          'std::cout << "\\"$fieldName\\" is not an Anthem model or collection of Anthem models, so the update could not be forwarded." << std::endl;');
      writer.writeLine(
          'std::cout << "\\"$fieldName\\" is of type \\"${field.typeInfo.name}\\"." << std::endl;');
    }

    void writeSerializedValueNullCheck() {
      writer.writeLine('if (!request.serializedValue.has_value()) {');
      writer.incrementWhitespace();
      writer.writeLine(
          'std::cout << "Serialized value is null, but shouldn\'t be in this context." << std::endl;');
      writer.writeLine('return;');
      writer.decrementWhitespace();
      writer.writeLine('}');
    }

    void writeIndexCheckForPrimitive() {
      writer.writeLine(
          'if (request.fieldAccesses.size() > fieldAccessIndex + 1) {');
      writer.incrementWhitespace();
      writeInvalidAccessWarning();
      writer.writeLine('return;');
      writer.decrementWhitespace();
      writer.writeLine('}');
    }

    void writeUpdateTypeInvalidError(_FieldUpdateKind updateKind) {
      writer.writeLine(
          'std::cout << "Invalid update type for \\"$fieldName\\" on model \\"${context.annotatedClass.name}\\"" << std::endl;');
      writer.writeLine(
          'std::cout << "Update type \\"${updateKind.name}\\" is not valid for field \\"$fieldName\\"." << std::endl;');
    }

    void writeUpdate({
      required ModelType type,
      required _FieldUpdateKind updateKind,
      String? assignmentTarget,
    }) {
      switch (type) {
        case StringModelType():
          assignmentTarget!;
          if (updateKind != _FieldUpdateKind.set) {
            writeUpdateTypeInvalidError(updateKind);
            return;
          }

          writeIndexCheckForPrimitive();
          writeSerializedValueNullCheck();

          final stringGetter =
              'request.serializedValue.value().substr(1, request.serializedValue.value().size() - 2)';

          if (type.isNullable) {
            writer
                .writeLine('if (request.serializedValue.value() == "null") {');
            writer.incrementWhitespace();
            writer.writeLine('$assignmentTarget = std::nullopt;');
            writer.decrementWhitespace();
            writer.writeLine('} else {');
            writer.incrementWhitespace();
            writer.writeLine(
                '$assignmentTarget = std::optional<std::string>($stringGetter);');
            writer.decrementWhitespace();
            writer.writeLine('}');
          } else {
            writer.writeLine('$assignmentTarget = $stringGetter;');
          }

          break;
        case IntModelType():
          assignmentTarget!;
          if (updateKind != _FieldUpdateKind.set) {
            writeUpdateTypeInvalidError(updateKind);
            return;
          }

          writeIndexCheckForPrimitive();
          writeSerializedValueNullCheck();

          if (type.isNullable) {
            writer
                .writeLine('if (request.serializedValue.value() == "null") {');
            writer.incrementWhitespace();
            writer.writeLine('$assignmentTarget = std::nullopt;');
            writer.decrementWhitespace();
            writer.writeLine('} else {');
            writer.incrementWhitespace();
            writer.writeLine(
                '$assignmentTarget = std::optional<int64_t>(std::stoll(request.serializedValue.value()));');
            writer.decrementWhitespace();
            writer.writeLine('}');
          } else {
            writer.writeLine(
                '$assignmentTarget = std::stoll(request.serializedValue.value());');
          }
          break;
        case DoubleModelType() || NumModelType():
          assignmentTarget!;
          if (updateKind != _FieldUpdateKind.set) {
            writeUpdateTypeInvalidError(updateKind);
            return;
          }

          writeIndexCheckForPrimitive();
          writeSerializedValueNullCheck();

          if (type.isNullable) {
            writer
                .writeLine('if (request.serializedValue.value() == "null") {');
            writer.incrementWhitespace();
            writer.writeLine('$assignmentTarget = std::nullopt;');
            writer.decrementWhitespace();
            writer.writeLine('} else {');
            writer.incrementWhitespace();
            writer.writeLine(
                '$assignmentTarget = std::optional<double>(std::stod(request.serializedValue.value()));');
            writer.decrementWhitespace();
            writer.writeLine('}');
          } else {
            writer.writeLine(
                '$assignmentTarget = std::stod(request.serializedValue.value());');
          }
          break;
        case BoolModelType():
          assignmentTarget!;
          if (updateKind != _FieldUpdateKind.set) {
            writeUpdateTypeInvalidError(updateKind);
            return;
          }

          writeIndexCheckForPrimitive();
          writeSerializedValueNullCheck();

          if (type.isNullable) {
            writer
                .writeLine('if (request.serializedValue.value() == "null") {');
            writer.incrementWhitespace();
            writer.writeLine('$assignmentTarget = std::nullopt;');
            writer.decrementWhitespace();
            writer.writeLine('} else {');
            writer.incrementWhitespace();
            writer.writeLine(
                '$assignmentTarget = std::optional<bool>(request.serializedValue.value() == "true");');
            writer.decrementWhitespace();
            writer.writeLine('}');
          } else {
            writer.writeLine(
                '$assignmentTarget = request.serializedValue.value() == "true";');
          }
          break;
        case EnumModelType():
          writeIndexCheckForPrimitive();
          break;
        case ColorModelType():
          writeIndexCheckForPrimitive();
          break;
        case ListModelType():
          // TODO: Implement
          break;
        case MapModelType():
          // TODO: Implement
          break;
        case CustomModelType() || UnknownModelType():
          assignmentTarget!;
          if (updateKind != _FieldUpdateKind.set) {
            writeUpdateTypeInvalidError(updateKind);
            return;
          }

          // If this field is a custom model and this is the last accessor in the
          // chain, then we should deserialize the provided JSON into this field.
          writer.writeLine(
              'if (request.fieldAccesses.size() == fieldAccessIndex + 1) {');
          writer.incrementWhitespace();
          writeSerializedValueNullCheck();
          writer.writeLine(
              'auto result = rfl::json::read<${getCppType(type)}>(request.serializedValue.value());');
          writer.writeLine('auto error = result.error();');

          writer.writeLine('if (error.has_value()) {');
          writer.incrementWhitespace();
          writer.writeLine(
              'std::cout << "Error deserializing $fieldName:" << std::endl << error.value().what() << std::endl;');
          writer.writeLine('return;');
          writer.decrementWhitespace();
          writer.writeLine('} else {');
          writer.incrementWhitespace();
          writer.writeLine('$assignmentTarget = result.value();');
          writer.decrementWhitespace();
          writer.writeLine('}');

          writer.decrementWhitespace();

          // If this field is a custom model and this is not the last accessor in
          // the chain, then we should forward the update to the child.
          writer.writeLine('} else {');
          writer.incrementWhitespace();
          var nullable = '';
          if (type.isNullable) {
            writer.writeLine('if ($assignmentTarget.has_value()) {');
            writer.incrementWhitespace();
            nullable = '.value()';
          }
          writer.writeLine(
              '$assignmentTarget$nullable->handleModelUpdate(request, fieldAccessIndex + 1);');
          if (type.isNullable) {
            writer.decrementWhitespace();
            writer.writeLine('} else {');
            writer.incrementWhitespace();
            writer.writeLine(
                'std::cout << "Field $fieldName is null, so the update could not be forwarded." << std::endl;');
            writer.decrementWhitespace();
            writer.writeLine('}');
          }
          writer.decrementWhitespace();
          writer.writeLine('}');

          break;
      }
    }

    writer.writeLine('if (request.updateKind == FieldUpdateKind::set) {');
    writer.incrementWhitespace();
    writeUpdate(
      type: field.typeInfo,
      updateKind: _FieldUpdateKind.set,
      assignmentTarget: 'this->$fieldName',
    );
    writer.decrementWhitespace();
    writer
        .writeLine('} else if (request.updateKind == FieldUpdateKind::add) {');
    writer.incrementWhitespace();
    writeUpdate(
      type: field.typeInfo,
      updateKind: _FieldUpdateKind.add,
      assignmentTarget: 'this->$fieldName',
    );
    writer.decrementWhitespace();
    writer.writeLine(
        '} else if (request.updateKind == FieldUpdateKind::remove) {');
    writer.incrementWhitespace();
    writeUpdate(
      type: field.typeInfo,
      updateKind: _FieldUpdateKind.remove,
      assignmentTarget: 'this->$fieldName',
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

enum _FieldUpdateKind { set, add, remove }
