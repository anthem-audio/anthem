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

/// Defines a shared interface for processors.
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
interface class Processor {}
