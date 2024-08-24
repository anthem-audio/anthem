/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

import 'package:anthem_codegen/annotations.dart';

part 'project.dart';
part 'processing_graph.dart';
part 'processors.dart';

part 'messages.g.dart';

class Exit extends Request {}

class ExitReply extends Response {}

class Heartbeat extends Request {}

class HeartbeatReply extends Response {}

// @AnthemModel(serializable: true)
sealed class Request extends _Request /*with _$RequestAnthemModelMixin*/ {
  Request();

  // factory Request.fromJson_ANTHEM(Map<String, dynamic> json) => _$RequestAnthemModelMixin.fromJson_ANTHEM(json);
}

class _Request {
  late int id;
}

// @AnthemModel(serializable: true)
sealed class Response extends _Response /*with _$ResponseAnthemModelMixin*/ {
  Response();

  // factory Response.fromJson_ANTHEM(Map<String, dynamic> json) => _$ResponseAnthemModelMixin.fromJson_ANTHEM(json);
}

class _Response {
  late int id;
}
