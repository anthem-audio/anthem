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

void writeModelSyncFn(
    {required Writer writer, required ModelClassInfo context}) {
  writer.writeLine(
      'void handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex) {');
  writer.incrementWhitespace();

  var isFirst = true;

  for (var MapEntry(key: fieldName, value: field) in context.fields.entries) {
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

    switch (field.typeInfo) {
      case StringModelType():
        writeIndexCheckForPrimitive();
        writeSerializedValueNullCheck();

        if (field.typeInfo.isNullable) {
          writer.writeLine('if (request.serializedValue.value() == "null") {');
          writer.incrementWhitespace();
          writer.writeLine('this->$fieldName = std::nullopt;');
          writer.decrementWhitespace();
          writer.writeLine('} else {');
          writer.incrementWhitespace();
          writer.writeLine(
              'this->$fieldName = std::optional<std::string>(request.serializedValue.value().substr(1, request.serializedValue.value().size() - 2));');
          writer.decrementWhitespace();
          writer.writeLine('}');
        } else {
          writer
              .writeLine('this->$fieldName = request.serializedValue.value();');
        }

        break;
      case IntModelType():
        writeIndexCheckForPrimitive();
        break;
      case DoubleModelType():
        writeIndexCheckForPrimitive();
        break;
      case NumModelType():
        writeIndexCheckForPrimitive();
        break;
      case BoolModelType():
        writeIndexCheckForPrimitive();
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
        // If this field is a custom model and this is the last accessor in the
        // chain, then we should deserialize the provided JSON into this field.
        writer.writeLine(
            'if (request.fieldAccesses.size() == fieldAccessIndex + 1) {');
        writer.incrementWhitespace();
        writeSerializedValueNullCheck();
        writer.writeLine(
            'auto result = rfl::json::read<${getCppType(field.typeInfo)}>(request.serializedValue.value());');
        writer.writeLine('auto error = result.error();');

        writer.writeLine('if (error.has_value()) {');
        writer.incrementWhitespace();
        writer.writeLine(
            'std::cout << "Error deserializing $fieldName:" << std::endl << error.value().what() << std::endl;');
        writer.writeLine('return;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine('this->$fieldName = result.value();');
        writer.decrementWhitespace();
        writer.writeLine('}');

        writer.decrementWhitespace();

        // If this field is a custom model and this is not the last accessor in
        // the chain, then we should forward the update to the child.
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        var nullable = '';
        if (field.typeInfo.isNullable) {
          writer.writeLine('if (this->$fieldName.has_value()) {');
          writer.incrementWhitespace();
          nullable = '.value()';
        }
        writer.writeLine(
            'this->$fieldName$nullable->handleModelUpdate(request, fieldAccessIndex + 1);');
        if (field.typeInfo.isNullable) {
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

    writer.decrementWhitespace();
    writer.writeLine('}');

    isFirst = false;
  }

  writer.decrementWhitespace();
  writer.writeLine('}');
}
