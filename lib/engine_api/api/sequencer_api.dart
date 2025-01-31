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

part of 'package:anthem/engine_api/engine.dart';

class SequencerApi {
  final Engine _engine;

  SequencerApi(this._engine);

  void compileArrangement(Id arrangementId, {List<String>? channelsToRebuild}) {
    var request = CompileSequenceRequest.arrangement(
      id: _engine._getRequestId(),
      arrangementId: arrangementId.toString(),
      channelsToRebuild: channelsToRebuild,
    );

    _engine._request(request);
  }

  void compilePattern(Id patternId, {List<String>? channelsToRebuild}) {
    var request = CompileSequenceRequest.pattern(
      id: _engine._getRequestId(),
      patternId: patternId.toString(),
      channelsToRebuild: channelsToRebuild,
    );

    _engine._request(request);
  }
}
