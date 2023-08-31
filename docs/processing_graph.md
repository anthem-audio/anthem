# Graph Model for Audio Processing

Anthem will use a node graph to route audio, control and note data between plugins and through to a master audio output node. The movement of data through the graph will be driven by the sequencer.

This node processing graph has two components: nodes and connections. Nodes can take zero or more inputs and produce zero or more outputs in three different data types: note commands (on, off, etc.), audio samples, and audio-rate control values.

## Pre-calculating processing steps

The processing graph is stored in the main thread and compiled into a set of parallelizable processing instructions. When the graph topology is updated, these instructions are recompiled and pushed to the audio thread via a thread-safe buffer, at which point the audio thread releases its old instructions and allows them to be deallocated by the main thread.

### A note on delay compensation

The above section needs to be thought through more thoroughly, especially in the context of PDC. With no PDC, all data is completely transient; or in other words, data set from one node to another doesn't need to be buffered by the DAW itself. PDC introduces a complication to this. For each processing cycle, a plugin with a PDC delay on the output must effectively send old data. It will process a more up-to-date stream, but the PDC delay requires the new output data to be buffered and old output data to be sent instead.

This means we must preserve a buffer for each audio output. This could be done with a dedicated node, but I think it should be wrapped into the model for each node as this seems to me to be more ergonomic (a dedicated node means each node is really n + 1 nodes where n is the number of outputs). This introduces the challenge of coordinating the audio and main threads here, and I'm not sure how to best accomplish this. We only need to coordinate when the buffer size needs to change (I suppose to avoid performing allocation or deallocation on the audio thread?), but I'm not sure if it's acceptable for this update to not be real-time safe.

## Plugin delay compensation

Plugin delay compensation (PDC) is a feature that allows processing delay in plugins to be corrected by the DAW. Some types of effects, such as EQ, filters and multiband processors, introduce delay into the signal by necessity due to how they perform their processing.

For example, if an audio engineer wants to mix the dry and wet signals of a plugin that introduces delay, the mixed signal will contain phasing artifacts due to the mismatched delay.

The solution to this simple example is to compensate for the time offset by introducing an artificial delay to the dry signal that matches the delay reported by the plugin. However, this is far from a general solution. A general solution will require analyzing the graph and producing a set of delay compensations which accounts for any arbitrary delay in the graph.

## Unique challenges

<!-- Open question: can plugins change their delay during processing? -->

<!-- Must the graph always be acyclic? It seems good to do this for audio, but what about the output of a peak controller? -->
