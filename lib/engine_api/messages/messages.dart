/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

import 'package:anthem_codegen/include/annotations.dart';

part 'model_sync.dart';
part 'processing_graph.dart';
part 'sequencer.dart';
part 'visualization.dart';

part 'messages.g.dart';

class Exit extends Request {
  Exit.uninitialized();

  Exit({required int id}) {
    super.id = id;
  }
}

class ExitReply extends Response {
  ExitReply.uninitialized();

  ExitReply({required int id}) {
    super.id = id;
  }
}

class Heartbeat extends Request {
  Heartbeat.uninitialized();

  Heartbeat({required int id}) {
    super.id = id;
  }
}

class HeartbeatReply extends Response {
  HeartbeatReply.uninitialized();

  HeartbeatReply({required int id}) {
    super.id = id;
  }
}

/// Unsolicited response that is sent back one time, when the audio device has
/// initialized.
class AudioReadyEvent extends Response {
  AudioReadyEvent.uninitialized();

  AudioReadyEvent({required int id}) {
    super.id = id;
  }
}

@AnthemModel.ipc()
sealed class Request extends _Request with _$RequestAnthemModelMixin {
  Request();

  factory Request.fromJson(Map<String, dynamic> json) =>
      _$RequestAnthemModelMixin.fromJson(json);
}

class _Request {
  late int id;
}

@AnthemModel.ipc()
sealed class Response extends _Response with _$ResponseAnthemModelMixin {
  Response();

  factory Response.fromJson(Map<String, dynamic> json) =>
      _$ResponseAnthemModelMixin.fromJson(json);
}

class _Response {
  late int id;
}
