/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

part of 'messages.dart';

class CompileProcessingGraphRequest extends Request {
  CompileProcessingGraphRequest.uninitialized();

  CompileProcessingGraphRequest({required int id}) {
    super.id = id;
  }
}

class CompileProcessingGraphResponse extends Response {
  late bool success;
  String? error;

  CompileProcessingGraphResponse.uninitialized();

  CompileProcessingGraphResponse({
    required int id,
    required this.success,
    this.error,
  }) {
    super.id = id;
  }
}
