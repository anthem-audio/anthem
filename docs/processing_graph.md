# Graph Model for Audio Processing

Anthem uses a node graph to route audio, control and note data between plugins and through to a master audio output node. This graph has two components: nodes and connections. Nodes can take zero or more inputs and produce zero or more outputs in three different data types: note commands (on, off, etc.), audio samples, and audio-rate control values.

Processors in Anthem are defined as nodes in this graph. Processors can take inputs in any of the three data types, define processing routines for operating on these inputs and/or synthesizing new data, and produce outputs in any of the three data types.

Connections can be defined from any input to any output of the same data type. Anthem's processing graph module is responsible for transporting data along connections in the graph, and for calling the processing routines on processors in the graph.

## Pre-calculating processing steps

The processing graph is stored in the main thread and compiled into a set of parallelizable processing instructions. When the graph topology is updated, these instructions are recompiled and pushed to the audio thread, at which point the audio thread releases its old instructions and allows them to be deallocated by the main thread.

This is done for two reasons. First, it is non-trivial to traverse this graph. Pre-computing the processing instructions on the main thread saves the audio thread a lot of work. Second, pre-processing these steps opens the door to a fully generic multithreaded solution to audio processing in the future.

## Plugin delay compensation

Plugin delay compensation (PDC) is a feature that allows processing delay in plugins to be corrected by the DAW. Some types of effects, such as EQ, filters and multiband processors, introduce delay into the signal by necessity due to how they perform their processing.

For example, if an audio engineer wants to mix the dry and wet signals of a plugin that introduces delay, the mixed signal will contain phasing artifacts due to the mismatched delay. With PDC, these artifacts will not be present.

Anthem's processing graph does not yet support this.

<!-- ## Unique challenges -->

<!-- Open question: can plugins change their delay during processing? -->

<!-- Must the graph always be acyclic? It seems good to do this for audio, but what about the output of a peak controller? -->
