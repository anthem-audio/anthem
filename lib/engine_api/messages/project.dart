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

part of 'messages.dart';

class AddArrangementRequest extends Request {
  AddArrangementRequest.uninitialized();

  AddArrangementRequest({required int id}) {
    super.id = id;
  }
}

class AddArrangementResponse extends Response {
  late int editId;

  AddArrangementResponse.uninitialized();

  AddArrangementResponse({
    required int id,
    required this.editId,
  }) {
    super.id = id;
  }
}

class DeleteArrangementRequest extends Request {
  late int editId;

  DeleteArrangementRequest.uninitialized();

  DeleteArrangementRequest({
    required int id,
    required this.editId,
  }) {
    super.id = id;
  }
}

// Maybe these should be moved out into another file
class LiveNoteOnRequest extends Request {
  late int editId;

  // how on earth are we linking things
  late int channel;
  late int note;
  late double velocity; // JUCE apparently encodes this in float

  LiveNoteOnRequest.uninitialized();

  LiveNoteOnRequest({
    required int id,
    required this.editId,
    required this.channel,
    required this.note,
    required this.velocity,
  }) {
    super.id = id;
  }
}

class LiveNoteOffRequest extends Request {
  late int editId;

  late int channel;
  late int note;

  LiveNoteOffRequest.uninitialized();

  LiveNoteOffRequest({
    required int id,
    required this.editId,
    required this.channel,
    required this.note,
  }) {
    super.id = id;
  }
}
