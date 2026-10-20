/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/model/project.dart';

/// Builds a prealpha.1 fixture with the older arrangement and parameter fields.
Map<String, dynamic> createPrealpha1ProjectJson(ProjectModel project) {
  final projectJson = project.toJson()
    ..['savedInSoftwareVersion'] = '0.0.0-prealpha.1';
  final sequence = projectJson['sequence'] as Map<String, dynamic>;
  final arrangement = sequence.remove('arrangement') as Map<String, dynamic>;
  final arrangementId = arrangement['id'] as int;

  sequence['arrangements'] = <String, dynamic>{
    arrangementId.toString(): arrangement,
  };
  sequence['arrangementOrder'] = <int>[arrangementId];

  final nodes = projectJson['processingGraph']['nodes'] as Map;
  for (final node in nodes.values) {
    for (final group in [
      'audioInputPorts',
      'audioOutputPorts',
      'eventInputPorts',
      'eventOutputPorts',
      'controlInputPorts',
      'controlOutputPorts',
    ]) {
      for (final port in node[group] as List) {
        final presentation = port.remove('presentation') as Map;
        final resetValue = port.remove('parameterResetValue');
        final parameter = port['config']['parameterConfig'] as Map?;
        if (parameter == null) continue;
        final factoryDefault = parameter.remove('factoryDefaultValue');
        parameter['defaultValue'] = resetValue ?? factoryDefault;
        parameter['normalizedVisualBaseline'] =
            presentation['normalizedVisualBaseline'];
      }
    }
  }

  return projectJson;
}
