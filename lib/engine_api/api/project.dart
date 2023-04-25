/*
  Copyright (C) 2023 Joshua Wade

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

class Project {
  Engine engine;

  Project(this.engine);

  Future<List<String>> getPlugins() {
    final completer = Completer<List<String>>();

    final id = engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.GetPlugins,
      command: GetPluginsObjectBuilder(),
    );

    engine._request(id, request, onResponse: (response) {
      final inner = response.returnValue as GetPluginsResponse;
      completer.complete(inner.plugins!);
    });

    return completer.future;
  }
}
