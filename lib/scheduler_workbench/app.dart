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

import 'package:flutter/material.dart';

import 'canvas/graph_canvas.dart';
import 'store.dart';
import 'view_model.dart';
import 'widgets/generation_panel.dart';

class WorkbenchApp extends StatefulWidget {
  const WorkbenchApp({super.key});

  @override
  State<WorkbenchApp> createState() => _WorkbenchAppState();
}

class _WorkbenchAppState extends State<WorkbenchApp> {
  late final WorkbenchStore store = WorkbenchStore.demo();
  late final WorkbenchViewModel viewModel = WorkbenchViewModel();

  void _regenerateSession() {
    store.regenerateSession();
    viewModel.viewportOffset = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scheduler Workbench',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Scheduler Workbench')),
        body: Row(
          children: [
            GenerationPanel(
              settings: store.generationSettings,
              onRegenerate: _regenerateSession,
            ),
            Expanded(
              child: GraphCanvas(graph: store.graph, viewModel: viewModel),
            ),
          ],
        ),
      ),
    );
  }
}
