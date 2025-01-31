/*
  Copyright (C) 2025 Joshua Wade

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

/// A request to compile either a pattern or an arrangement.
class CompileSequenceRequest extends Request {
  /// The channel IDs to rebuild.
  ///
  /// If unspecified, all channels will be rebuilt.
  List<String>? channelsToRebuild;

  /// The pattern ID to compile.
  ///
  /// Either this or [arrangementId] must be specified.
  String? patternId;

  /// The arrangement ID to compile.
  ///
  /// Either this or [patternId] must be specified.
  String? arrangementId;

  CompileSequenceRequest.uninitialized();

  /// Creates a request to compile a pattern.
  CompileSequenceRequest.pattern({
    required int id,
    required this.patternId,
    this.channelsToRebuild,
  }) {
    super.id = id;
  }

  /// Creates a request to compile an arrangement.
  CompileSequenceRequest.arrangement({
    required int id,
    required this.arrangementId,
    this.channelsToRebuild,
  }) {
    super.id = id;
  }
}
