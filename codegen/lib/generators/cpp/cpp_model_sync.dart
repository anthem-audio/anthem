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

/// Generates a C++ function that takes a given update message, and uses it to
/// sync the given model.
///
/// The C++ method generated by this function will look something like this:
///
/// ```cpp
/// void MyModel::handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex) {
///   if (request.fieldAccesses[fieldAccessIndex]->fieldName == "myFirstField") {
///     this->myFirstField = std::stoll(request.serializedValue.value());
///   } else if (request.fieldAccesses[fieldAccessIndex]->fieldName == "mySecondField") {
///     // etc...
///   }
/// }
/// ```
///
/// Anthem also uses code generation for our messaging system, so the
/// `ModelUpdateRequest` class is defined in Dart (see
/// `lib/engine_api/messages/model_sync.dart`) and generated into C++ as well,
/// into `messages/messages.h`. The C++ method generated by this function takes
/// a `ModelUpdateRequest`, and if that request is for a field that exists on
/// the model, it will update that field with the provided value. If it is
/// instead for a field on a child model, it will forward the request to that
/// child model.
String getModelSyncFn(ModelClassInfo context) {
  final writer = Writer();

  writer.writeLine(
      'void ${context.annotatedClass.name}::handleModelUpdate(ModelUpdateRequest& request, int fieldAccessIndex) {');
  writer.incrementWhitespace();

  var isFirst = true;

  writer.writeLine(
      'auto& fieldName = request.fieldAccesses[fieldAccessIndex]->fieldName;');

  for (var MapEntry(key: fieldName, value: field) in context.fields.entries) {
    if (field.hideAnnotation?.cpp == true) {
      continue;
    }

    writer
        .writeLine('${isFirst ? '' : 'else '}if (fieldName == "$fieldName") {');
    writer.incrementWhitespace();

    _writeUpdate(
      context: context,
      writer: writer,
      type: field.typeInfo,
      createFieldSetter: (value) => 'this->$fieldName = $value;',
      fieldAccessExpression: 'this->$fieldName',
    );

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

void _writeSerializedValueNullCheck({
  required Writer writer,
  required String fieldAccessExpression,
  required ModelClassInfo context,
}) {
  writer.writeLine('if (!request.serializedValue.has_value()) {');
  writer.incrementWhitespace();
  writer.writeLine(
      'std::cout << "Error updating accessor \\"$fieldAccessExpression\\" on model \\"${context.annotatedClass.name}\\"." << std::endl;');
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
  required String updateKind,
  required ModelType type,
  required String fieldAccessExpression,
}) {
  writer.writeLine(
      'std::cout << "Invalid update type for accessor \\"$fieldAccessExpression\\" on model \\"${context.annotatedClass.name}\\"" << std::endl;');
  writer.writeLine(
      'std::cout << "Update type \\"$updateKind\\" is not valid for field \\"$fieldAccessExpression\\" of type ${type.toString()}." << std::endl;');
}

void _writeJsonResultCheck({
  required Writer writer,
  required String resultVariable,
  required ModelClassInfo context,
  required String fieldAccessExpression,
}) {
  writer.writeLine('auto error = $resultVariable.error();');
  writer.writeLine('if (error.has_value()) {');
  writer.incrementWhitespace();
  writer.writeLine(
      'std::cout << "Error deserializing to field \\"$fieldAccessExpression\\" in model \\"${context.annotatedClass.name}\\":" << std::endl << error.value().what() << std::endl;');
  writer.writeLine('return;');
  writer.decrementWhitespace();
  writer.writeLine('}');
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
///   //   modificationTarget: 'this->myMapField[request.fieldAccesses[fieldAccessIndex + 1]->serializedValue.value()]',
///   // );
/// }
/// // Etc...
/// ```
void _writeUpdate({
  required Writer writer,
  required ModelType type,
  required String Function(String valueExpression) createFieldSetter,
  required String fieldAccessExpression,
  required ModelClassInfo context,
  int fieldAccessIndexMod = 0,
}) {
  void writeSetUpdateKindAssertion() {
    writer.writeLine('if (request.updateKind == FieldUpdateKind::add) {');
    writer.incrementWhitespace();
    _writeUpdateTypeInvalidError(
      writer: writer,
      context: context,
      updateKind: 'add',
      type: type,
      fieldAccessExpression: fieldAccessExpression,
    );
    writer.writeLine('return;');
    writer.decrementWhitespace();
    writer.writeLine(
        '} else if (request.updateKind == FieldUpdateKind::remove) {');
    writer.incrementWhitespace();
    _writeUpdateTypeInvalidError(
      writer: writer,
      context: context,
      updateKind: 'remove',
      type: type,
      fieldAccessExpression: fieldAccessExpression,
    );
    writer.writeLine('return;');
    writer.decrementWhitespace();
    writer.writeLine('}');
    writer.writeLine();
  }

  switch (type) {
    case StringModelType():
      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      writeSetUpdateKindAssertion();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );

      final stringGetter =
          'request.serializedValue.value().substr(1, request.serializedValue.value().size() - 2)';

      if (type.isNullable) {
        writer.writeLine('if (request.serializedValue.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine(createFieldSetter('std::nullopt'));
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            createFieldSetter('std::optional<std::string>($stringGetter)'));
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(createFieldSetter(stringGetter));
      }

      break;
    case IntModelType():
      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      writeSetUpdateKindAssertion();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );

      if (type.isNullable) {
        writer.writeLine('if (request.serializedValue.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine(createFieldSetter('std::nullopt'));
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(createFieldSetter(
            'std::optional<int64_t>(std::stoll(request.serializedValue.value()))'));
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            createFieldSetter('std::stoll(request.serializedValue.value())'));
      }
      break;
    case DoubleModelType() || NumModelType():
      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      writeSetUpdateKindAssertion();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );

      if (type.isNullable) {
        writer.writeLine('if (request.serializedValue.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine(createFieldSetter('std::nullopt'));
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(createFieldSetter(
            'std::optional<double>(std::stod(request.serializedValue.value()))'));
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            createFieldSetter('std::stod(request.serializedValue.value())'));
      }
      break;
    case BoolModelType():
      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      writeSetUpdateKindAssertion();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );

      if (type.isNullable) {
        writer.writeLine('if (request.serializedValue.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine(createFieldSetter('std::nullopt'));
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(createFieldSetter(
            'std::optional<bool>(request.serializedValue.value() == "true")'));
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            createFieldSetter('request.serializedValue.value() == "true"'));
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
      writeSetUpdateKindAssertion();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );

      // TODO: If this works, replicate this in the other types.
      writer.writeLine(
          'auto result = rfl::json::read<${getCppType(type)}>(request.serializedValue.value());');
      _writeJsonResultCheck(
        writer: writer,
        resultVariable: 'result',
        context: context,
        fieldAccessExpression: fieldAccessExpression,
      );
      writer.writeLine(createFieldSetter('result.value()'));

      break;
    case ColorModelType():
      _writeIndexCheckForPrimitive(
        writer: writer,
        context: context,
        type: type,
        fieldAccessIndexMod: fieldAccessIndexMod,
        fieldAccessExpression: fieldAccessExpression,
      );
      writeSetUpdateKindAssertion();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );

      writer.writeLine(
          'auto result = rfl::json::read<${getCppType(type)}>(request.serializedValue.value());');
      _writeJsonResultCheck(
        writer: writer,
        resultVariable: 'result',
        context: context,
        fieldAccessExpression: fieldAccessExpression,
      );
      writer.writeLine(createFieldSetter('result.value()'));

      break;
    case ListModelType():
      // If the field is a list and this is *not* the last accessor in the
      // chain, then one of the two following things is true:
      //  1. The request is to add, set or remove a specific value in the list,
      //     in which case we should handle it by either adding, setting or
      //     removing the value.
      //  2. The request is to update some distant child whose parent lives in
      //     this list, in which case we should forward the request to the
      //     child.
      //
      // This if statement will be true if this concerns a specific index in the
      // list. This is because fieldAccessIndex refers to the index in the
      // accessor list that identifies the list itself, whereas fieldAccessIndex
      // + 1 refers to the index in the accessor list that identifies a
      // specific item in the list. If the list contains an item for
      // fieldAccessIndex + 1, then this is a request to update a specific item
      // in the list, or a request for a distant child of that item.
      writer.writeLine(
          'if (fieldAccessIndex + 1 + $fieldAccessIndexMod < request.fieldAccesses.size()) {');
      writer.incrementWhitespace();

      writer.writeLine(
          'if (!request.fieldAccesses[fieldAccessIndex + 1 + $fieldAccessIndexMod]->listIndex.has_value()) {');
      writer.incrementWhitespace();
      writer.writeLine(
          'std::cout << "Error processing list update for setter \\"${createFieldSetter("[value here]")}\\": list index is null." << std::endl;');
      writer.writeLine('return;');
      writer.decrementWhitespace();
      writer.writeLine('}');

      writer.writeLine(
          'if (request.updateKind == FieldUpdateKind::remove && request.fieldAccesses.size() - 1 == fieldAccessIndex + 1 + $fieldAccessIndexMod) {');
      writer.incrementWhitespace();
      writer.writeLine(
          '$fieldAccessExpression.erase($fieldAccessExpression.begin() + request.fieldAccesses[fieldAccessIndex + 1 + $fieldAccessIndexMod]->listIndex.value());');
      writer.decrementWhitespace();
      writer.writeLine(
          '} else if (request.updateKind == FieldUpdateKind::add && request.fieldAccesses.size() - 1 == fieldAccessIndex + 1 + $fieldAccessIndexMod) {');
      writer.incrementWhitespace();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );
      writer.writeLine('${getCppType(type.itemType)} itemResult;');
      _writeUpdate(
        context: context,
        writer: writer,
        type: type.itemType,
        fieldAccessExpression: 'itemResult',
        createFieldSetter: (value) => 'itemResult = $value;',
        fieldAccessIndexMod: fieldAccessIndexMod + 1,
      );
      writer.writeLine(
          '$fieldAccessExpression.insert($fieldAccessExpression.begin() + request.fieldAccesses[fieldAccessIndex + 1 + $fieldAccessIndexMod]->listIndex.value(), std::move(itemResult));');
      writer.decrementWhitespace();
      writer.writeLine('} else {');
      writer.incrementWhitespace();
      // This will either set the field in the list, or forward the request to
      // the child model represented by the field in the list.
      _writeUpdate(
        context: context,
        writer: writer,
        type: type.itemType,
        fieldAccessExpression:
            '$fieldAccessExpression[request.listIndex.value()]',
        createFieldSetter: (value) =>
            '$fieldAccessExpression[request.listIndex.value()] = $value;',
        fieldAccessIndexMod: fieldAccessIndexMod + 1,
      );
      writer.decrementWhitespace();
      writer.writeLine('}');

      // If this *is* the last accessor in the chain, then the provided JSON is
      // the new value for the entire list, and we should deserialize it into
      // this field.
      writer.decrementWhitespace();
      writer.writeLine('} else {');
      writer.incrementWhitespace();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );
      writeSetUpdateKindAssertion();

      writer.writeLine(
          'auto result = rfl::json::read<${getCppType(type)}>(request.serializedValue.value());');
      _writeJsonResultCheck(
        writer: writer,
        resultVariable: 'result',
        context: context,
        fieldAccessExpression: fieldAccessExpression,
      );
      writer.writeLine('$fieldAccessExpression = std::move(result.value());');

      writer.decrementWhitespace();
      writer.writeLine('}');
      break;
    case MapModelType():
      // If the field is a map and this is *not* the last accessor in the chain,
      // then one of the two following things is true:
      //  1. The request is to set or remove a specific value in the map, in
      //     which case we should handle it by either setting or removing the
      //     value.
      //  2. The request is to update some distant child whose parent lives in
      //     this map, in which case we should forward the request to the child.
      //
      // This if statement will be true if this concerns a specific key in the
      // map. This is because fieldAccessIndex refers to the index in the
      // accessor list that identifies the map itself, whereas fieldAccessIndex
      // + 1 refers to the index in the accessor list that identifies a specific
      // item in that map. If the list contains an item for fieldAccessIndex +
      // 1, then this is a request to update a specific item in the map, or a
      // request for a distant child of that item.
      writer.writeLine(
          'if (fieldAccessIndex + 1 + $fieldAccessIndexMod < request.fieldAccesses.size()) {');
      writer.incrementWhitespace();
      _writeKeyDeserialize(
        writer: writer,
        keyExpression:
            'request.fieldAccesses[fieldAccessIndex + 1 + $fieldAccessIndexMod]->serializedMapKey',
        keyType: type.keyType,
        outputVariable: 'deserializedKey',
      );

      writer.writeLine(
          'if (request.updateKind == FieldUpdateKind::remove && request.fieldAccesses.size() - 1 == fieldAccessIndex + 1 + $fieldAccessIndexMod) {');
      writer.incrementWhitespace();
      writer.writeLine('$fieldAccessExpression.erase(deserializedKey);');
      writer.decrementWhitespace();
      writer.writeLine(
          '} else if (request.updateKind == FieldUpdateKind::add && request.fieldAccesses.size() - 1 == fieldAccessIndex + 1 + $fieldAccessIndexMod) {');
      writer.incrementWhitespace();
      // "Add" is only valid for list. Should use "set" instead.
      _writeUpdateTypeInvalidError(
        writer: writer,
        context: context,
        updateKind: 'add',
        type: type,
        fieldAccessExpression: fieldAccessExpression,
      );
      writer.decrementWhitespace();
      writer.writeLine('} else {');
      writer.incrementWhitespace();

      // This will handle setting the value or forwarding the value, depending
      // on which is needed. We only have to explicitly handle deletion here,
      // which we do above.
      _writeUpdate(
        context: context,
        writer: writer,
        type: type.valueType,
        fieldAccessExpression: '$fieldAccessExpression[deserializedKey]',
        createFieldSetter: (value) =>
            '$fieldAccessExpression.insert_or_assign(deserializedKey, $value);',
        fieldAccessIndexMod: fieldAccessIndexMod + 1,
      );

      writer.decrementWhitespace();
      writer.writeLine('}');

      // If this *is* the last accessor in the chain, then the provided JSON is
      // the new value for the entire map, and we should deserialize it into
      // this field.
      writer.decrementWhitespace();
      writer.writeLine('} else {');
      writer.incrementWhitespace();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );
      writeSetUpdateKindAssertion();

      writer.writeLine(
          'auto result = rfl::json::read<${getCppType(type)}>(request.serializedValue.value());');
      _writeJsonResultCheck(
        writer: writer,
        resultVariable: 'result',
        context: context,
        fieldAccessExpression: fieldAccessExpression,
      );
      writer.writeLine(createFieldSetter('std::move(result.value())'));

      writer.decrementWhitespace();
      writer.writeLine('}');
      break;
    case CustomModelType() || UnknownModelType():
      // If this field is a custom model and this is the last accessor in the
      // chain, then we should deserialize the provided JSON into this field.
      writer.writeLine(
          'if (request.fieldAccesses.size() == fieldAccessIndex + 1 + $fieldAccessIndexMod) {');
      writer.incrementWhitespace();
      writeSetUpdateKindAssertion();
      _writeSerializedValueNullCheck(
        writer: writer,
        fieldAccessExpression: fieldAccessExpression,
        context: context,
      );

      writer.writeLine(
          'auto result = rfl::json::read<${getCppType(type)}>(request.serializedValue.value());');
      _writeJsonResultCheck(
        writer: writer,
        resultVariable: 'result',
        context: context,
        fieldAccessExpression: fieldAccessExpression,
      );
      writer.writeLine(createFieldSetter('std::move(result.value())'));

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

void _writeKeyDeserialize({
  required Writer writer,
  required String keyExpression,
  required ModelType keyType,
  required String outputVariable,
}) {
  if (!keyType.canBeMapKey) {
    throw ArgumentError(
        'The provided key type, ${keyType.name}, cannot be used as a map key.');
  }

  void writeKeyExistsCheck() {
    writer.writeLine('if (!$keyExpression.has_value()) {');
    writer.incrementWhitespace();
    writer.writeLine(
        'std::cout << "Error deserializing map key: key is null." << std::endl;');
    writer.writeLine('return;');
    writer.decrementWhitespace();
    writer.writeLine('}');
  }

  switch (keyType) {
    case StringModelType():
      writeKeyExistsCheck();
      if (keyType.isNullable) {
        writer.writeLine('std::optional<std::string> $outputVariable;');
        writer.writeLine('if ($keyExpression.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine('$outputVariable = std::nullopt;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            '$outputVariable = std::optional<std::string>($keyExpression.value().substr(1, $keyExpression.value().size() - 2));');
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            'auto $outputVariable = $keyExpression.value().substr(1, $keyExpression.value().size() - 2);');
      }
      break;
    case IntModelType():
      writeKeyExistsCheck();
      if (keyType.isNullable) {
        writer.writeLine('std::optional<int64_t> $outputVariable;');
        writer.writeLine('if ($keyExpression.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine('$outputVariable = std::nullopt;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            '$outputVariable = std::optional<int64_t>(std::stoll($keyExpression.value()));');
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            'auto $outputVariable = std::stoll($keyExpression.value());');
      }

      break;
    case DoubleModelType() || NumModelType():
      writeKeyExistsCheck();
      if (keyType.isNullable) {
        writer.writeLine('std::optional<double> $outputVariable;');
        writer.writeLine('if ($keyExpression.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine('$outputVariable = std::nullopt;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            '$outputVariable = std::optional<double>(std::stod($keyExpression.value()));');
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            'auto $outputVariable = std::stod($keyExpression.value());');
      }

      break;
    case BoolModelType():
      writeKeyExistsCheck();
      if (keyType.isNullable) {
        writer.writeLine('std::optional<bool> $outputVariable;');
        writer.writeLine('if ($keyExpression.value() == "null") {');
        writer.incrementWhitespace();
        writer.writeLine('$outputVariable = std::nullopt;');
        writer.decrementWhitespace();
        writer.writeLine('} else {');
        writer.incrementWhitespace();
        writer.writeLine(
            '$outputVariable = std::optional<bool>($keyExpression.value() == "true");');
        writer.decrementWhitespace();
        writer.writeLine('}');
      } else {
        writer.writeLine(
            'auto $outputVariable = $keyExpression.value() == "true";');
      }

      break;
    case EnumModelType():
      throw UnimplementedError(
          'Enums are not yet supported as map keys. This can be implemented in the future if the need arises.');
    case ListModelType() ||
          MapModelType() ||
          ColorModelType() ||
          CustomModelType() ||
          UnknownModelType():
      throw Exception(
          'These types should not be marked as map keys, and so should be caught above. This is a bug.');
  }
}
