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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';

/// Defines shared behavior for processors.
///
/// Models are defined by two classes, a private base class (`_MyModel`) and a
/// public class that extends the base class (`MyModel`). This must be mixed in
/// to the public class, since it relies on behavior provided by that base
/// class.
///
/// ### Background
///
/// NodeModel is a generic wrapper that defines audio routing within Anthem.
/// Each node also contains a processor. A node has a set of ports (which are
/// defined by the processor), and nodes can also have connections defined
/// between their ports, though this happens externally. The node then delegates
/// its actual DSP to a processor.
///
/// Each processor has a static node generator that produces a specific node to
/// represent it. The processor expects specific inputs and outputs, and so it
/// must create a node that is specifically tailored to itself.
///
/// The C++ backing class for each processor actually contains the DSP
/// implementation. It also inherits AnthemProcessor, which acts as an interface
/// class that defines a contract for how the rest of the engine will interact
/// with "a processor", as opposed to a specific processor, e.g. GainProcessor.
///
/// Critically, this AnthemProcessor interface class is really only applicable
/// to the engine, so it is only defined there. But as it turns out, there is a
/// need in the UI as well to be able to define a contract for what a processor
/// should be able to provide. This interface is that contract.
mixin Processor on AnthemModelBase, ProjectModelGetterMixin {
  Id get nodeId;

  /// The node that this processor represents.
  ///
  /// This is only valid once this processor is wrapped in a node via
  /// [createNode].
  NodeModel get node => parent as NodeModel;

  /// Creates a node that contains this processor.
  ///
  /// The node defines the allowed ports, so each processor must define this
  /// method and generate a valid NodeModel that can represent it.
  NodeModel createNode();
}
