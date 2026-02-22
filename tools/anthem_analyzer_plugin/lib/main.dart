import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/invalid_union_assignment_rule.dart';

final plugin = AnthemAnalyzerPlugin();

class AnthemAnalyzerPlugin extends Plugin {
  @override
  String get name => 'Anthem Analyzer Plugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(InvalidUnionAssignmentRule());
  }
}
