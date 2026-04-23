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

import 'generation/generation_settings.dart';
import 'generation/session_generator.dart';
import 'models/processing_graph.dart';
import 'models/session.dart';

class WorkbenchStore {
  final ProcessingGraphModel graph;
  final SessionModel session;
  final GenerationSettingsViewModel generationSettings;
  final SessionGenerator sessionGenerator;

  WorkbenchStore({
    required this.graph,
    required this.session,
    required this.generationSettings,
    required this.sessionGenerator,
  });

  factory WorkbenchStore.demo() {
    final store = WorkbenchStore(
      graph: ProcessingGraphModel(),
      session: SessionModel(),
      generationSettings: GenerationSettingsViewModel(),
      sessionGenerator: SessionGenerator(),
    );

    store.regenerateSession();
    return store;
  }

  void regenerateSession() {
    sessionGenerator.generate(
      graph: graph,
      session: session,
      settings: generationSettings.toSettings(),
    );
  }
}
