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

## Audio

Nodes in the processing graph can generate and consume audio streams. Audio outputs can go to multiple inputs, and multiple outputs can go to the same input. When multiple audio streams are routed into the same port, they are summed together additively before being given to the corresponding processor to process.

Consider the following graph:

```
 ________________       ____________________________
| GeneratorNode1 |     | Processor1                 |
|   AudioOutput1----.----AudioInput1   AudioOutput1--- ...
|________________|  |  |____________________________|
                    |
 ________________   |
| GeneratorNode2 |  |
|   AudioOutput1----*
|________________|
```

Each input port (in this case, just a single input) contains a buffer that is the same length as the block size, plus (in the future) an amount to account for any plugin delay compensation that is needed.

The compiler will produce the following steps for this graph:

1. Write zeros to the `AudioInput1` buffer on `Processor1`
2. Run the process method on `GeneratorNode1`, which will generate an output on its `AudioOutput1` buffer
3. Add the result of `GeneratorNode1`'s `AudioOutput1` buffer to the `AudioInput1` buffer on `Processor1`, and write this result back to the `AudioInput1` buffer
4. Same as step 2, but for `GeneratorNode2`
5. Same as step 3, but for `GeneratorNode2`

## Control values

Control values function in a very similar way to audio, in that they are represented as audio-rate streams of floating point values. There are, however, a few key differences:

1. Control values are always represented as a floating point between 0 and 1. This should represent the full parameter range, and there should not be any values beyond this range.

2. Control values are not summed additively. If a control input port has multiple connections, the most recent connection takes priority.

3. Control value signals can be "null", represented by NaN. "Null" values will take on the following real values, in descending priority:

   1. Less recently added connections with non-null values
   2. The most recent non-null value sent to the port
   3. The parameter's static value

### Parameters

In Anthem, all control inputs on nodes also function as parameters. Parameters augment control input ports by allowing the port to be given a constant numerical value to use instead of control input.

If a control input port has a connection, the control values that come through on that connection will always override the static parameter value. Otherwise, the control input will take on the static value provided through the parameter.

During playback, if the static value on a port is changed, it will override any connection value until playback is stopped and starts again.

## Note commands

Input and output ports for note commands are not yet supported by Anthem's processing graph.

<!-- ## Unique challenges -->

<!-- Open question: can plugins change their delay during processing? -->

<!-- Must the graph always be acyclic? It seems good to do this for audio, but what about the output of a peak controller? -->
