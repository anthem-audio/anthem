/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

// This file is probably the least intuitive part of the model codegen / sync
// system, so it warrants an explanation.
//
// For context, Anthem has a codebase that is split between Dart for the UI and
// C++ for the audio engine. The project model is defined in Dart, and there is
// a code generator in the codegen folder that reads each model file, defined in
// lib/model, and outputs a matching model file in C++, along with some code to
// facilitate syncing the two models.
//
// @GenerateCppModuleFile() below triggers the code generator to output
// something we call a "module" file in C++ - essentially just a big file that
// has #include statements for each file that is exported here. We import this
// module file in all hand-written C++ files as the intended method for
// referencing any generated C++ model classes.
//
// One reason this is potentially unintuitive, at least from the Dart
// perspective, is that C++ is sensitive to include order. If we reorder
// includes here, they will be reordered in the output file. This can cause
// issues due to compilation order. We try to forward-declare as much as
// possible, but there's only so much you can do. As a result, the order of
// imports in this file is specific to the needs of the C++ code, and changing
// the order here could break C++ compilation.
//
// The other reason this is potentially unintuitive is just that new model files
// *must* be referenced here in order to be usable in the C++ code.

@GenerateCppModuleFile()
library;

import 'package:anthem_codegen/include.dart';

export 'arrangement/arrangement.dart';
export 'arrangement/clip.dart';

export 'pattern/automation_lane.dart';
export 'pattern/automation_point.dart';
export 'pattern/note.dart';
export 'pattern/pattern.dart';

export 'processing_graph/processors/balance.dart';
export 'processing_graph/processors/gain.dart';
export 'processing_graph/processors/live_event_provider.dart';
export 'processing_graph/processors/master_output.dart';
export 'processing_graph/processors/sequence_note_provider.dart';
export 'processing_graph/processors/simple_midi_generator.dart';
export 'processing_graph/processors/simple_volume_lfo.dart';
export 'processing_graph/processors/tone_generator.dart';
export 'processing_graph/processors/utility.dart';
export 'processing_graph/processors/vst3_processor.dart';

export 'processing_graph/node_connection.dart';
export 'processing_graph/node_port_config.dart';
export 'processing_graph/node_port.dart';
export 'processing_graph/node.dart';
export 'processing_graph/parameter_config.dart';
export 'processing_graph/processing_graph.dart';

export 'shared/anthem_color.dart';
export 'shared/hydratable.dart';
export 'shared/loop_points.dart';
export 'shared/time_signature.dart';

export 'app.dart';
export 'project.dart';
export 'sequencer.dart';
export 'store.dart';
export 'track.dart';
