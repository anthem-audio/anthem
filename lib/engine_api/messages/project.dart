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

class AddArrangementRequest extends Request { }
class AddArrangementResponse extends Response {
  late int editId;
}

class DeleteArrangementRequest extends Request {
  late int editId;
}

// Maybe these should be moved out into another file
class LiveNoteOnRequest extends Request {
  late int editId;

  // how on earth are we linking things
  late int channel;
  late int note;
  late double velocity; // JUCE apparently encodes this in float
}
class LiveNoteOffRequest extends Request {
  late int editId;

  late int channel;
  late int note;
}
