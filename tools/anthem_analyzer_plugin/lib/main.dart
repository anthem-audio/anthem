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

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/invalid_union_assignment_rule.dart';
import 'src/rules/invalid_union_field_type_rule.dart';

final plugin = AnthemAnalyzerPlugin();

class AnthemAnalyzerPlugin extends Plugin {
  @override
  String get name => 'Anthem Analyzer Plugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(InvalidUnionAssignmentRule());
    registry.registerWarningRule(InvalidUnionFieldTypeRule());
  }
}
