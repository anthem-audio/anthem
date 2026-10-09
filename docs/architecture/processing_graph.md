# Graph Model for Audio Processing

Anthem uses a node graph to route audio, control and note data between plugins and through to a master audio output node. This graph has two components: nodes and connections. Nodes can take zero or more inputs and produce zero or more outputs in three different data types: events (note on, note off, etc.), audio samples, and audio-rate control values.

Processors in Anthem are defined as nodes in this graph. Processors can take inputs in any of the three data types, define processing routines for operating on these inputs and/or synthesizing new data, and produce outputs in any of the three data types.

Connections can be defined from any input to any output of the same data type. Anthem's processing graph module is responsible for transporting data along connections in the graph, and for calling the processing routines on processors in the graph.

## Processor initialization and port discovery

When a device is added, Anthem creates a node in the Dart project model to represent it. The node records which processor to use, its initial parameter values, and the ports that the UI expects to connect. Opening a project reconstructs this information from the project file, including the settings saved by the user.

The engine still needs to load and prepare the processor before it can process audio. It also needs to establish which ports exist and how many channels each audio port has. A saved port description may no longer match the installed plugin, and channel counts can depend on the active audio configuration. For example, the project can contain a connection to the master output before the engine knows whether the output device has two or four channels.

Processor initialization happens before the graph is compiled and sent to the audio thread. It gives the UI the current port descriptions and, for plugins, the parameter values after restoring the saved patch.

### Initial settings and saved settings

For a new native processor, the Dart factory chooses the initial parameter values. A regular track's utility processor, for example, starts with its gain at −10 dB. These values are stored on the node's control input ports. When a project is reopened, those ports contain the values from the project file instead. The regular model synchronization sends them to the engine. When the engine compiles the graph, it uses these values to initialize the parameters that the processor reads during audio processing.

A VST can also have settings that are not exposed as parameters. A synthesizer patch, for example, may contain plugin-specific data that Anthem cannot describe through control ports. Anthem stores the data returned by the plugin's state capture API in `NodeModel.processorState`, encoded as Base64. The engine passes that data back to the plugin when restoring it.

Saved VST parameter values on control ports let the UI show the last known values before the plugin loads. The saved plugin state is what restores the plugin itself. After restoration, the engine reads the plugin's current parameter values and updates the UI's copies.

### Restoring a plugin before reporting its ports

For a VST with saved plugin state, initialization runs in this order:

1. Create and prepare the plugin instance.
2. Restore the saved data from `processorState`.
3. Prepare the plugin again, since restoration may have changed its audio bus layout.
4. Return the final port descriptions and parameter values to the UI.

This order prevents the UI from applying the factory patch's values or port layout while the saved patch is still being restored. A new plugin without saved state only needs the first preparation before its results are returned.

The saved data is restored once for each processor instance. If the audio session restarts with a different sample rate or buffer size, the existing processor is prepared again and keeps its live settings. Starting a fresh engine process creates new processors, which restore the latest state held by the project model.

Anthem only captures live plugin state after initialization succeeds. If a plugin cannot load, saving the project preserves its previous `processorState` data. See [the initialization session](../../engine/src/modules/core/processing_graph_node_initialization_session.cpp) for the engine implementation.

### Updating cached port descriptions

Both native processors and VSTs return port descriptions through the same initialization response. Native C++ processors declare their ports in `prepareToProcess`. VST processors obtain their descriptions from JUCE. The response includes port names, audio channel counts, and parameter factory defaults and formatting information.

Before initialization, the UI can use the port IDs and parameter formatting provided by a Dart factory, or the descriptions cached in a project file. This lets it show controls and record connections while the engine is stopped. These ports start with `isAvailable` set to false. New native audio ports have no channel count yet, and their parameter factory defaults are filled in by the engine during initialization.

When the response arrives, `ProjectController._reconcilePorts` matches existing ports by ID and updates their descriptions in place. It keeps the same port objects, preserving their values, reset settings, visual settings and connections. Newly reported ports are added. A parameter's factory default is used only if it has no value yet; it does not replace a value supplied by the Dart factory or loaded from the project. Native values already exist in the synchronized model, so they do not need to be returned by the engine.

Port IDs must remain stable across software versions so saved connections and automation can refer to the same ports. Native IDs are defined as constants in the private Dart processor model class and exported to C++ through model codegen. See [model constants](../codegen/project_models/authoring_and_annotations.md#constants-are-supported).

### Parameter values, defaults and visual settings

A parameter's current value and its default are separate. Anthem also allows a project to choose a reset value that differs from the processor's factory default. For example, the utility processor's factory gain is 0 dB, while a regular track's utility starts at −10 dB and resets to −10 dB.

The model stores these values separately:

| Field | Purpose |
| --- | --- |
| `NodePortModel.parameterValue` | The current value used by a native processor, or the last known value read from a VST. |
| `ParameterConfigModel.factoryDefaultValue` | The processor's own default, reported by the engine. |
| `NodePortModel.parameterResetValue` | An optional project-specific reset value. If absent, reset uses the factory default when known. |
| `ParameterPresentationModel.normalizedVisualBaseline` | The value from which knob arcs and automation shading extend. |

Port names and channel counts belong to `NodePortConfigModel`, which also holds the parameter configuration. Visual settings belong to the project and are not sent to the engine. For example, a pan parameter can have a visual baseline of 0.5 so its knob arc and automation shading extend from the center. Updating the processor's port descriptions preserves that choice.

## Unavailable ports and saved routing

Anthem keeps unavailable ports in the project, together with their parameter values, visual settings and connections.

Each port has an `isAvailable` flag. Initialization sets it to true for ports reported by the engine and false for ports that are missing. The flag is sent to the engine but is not saved in project files: reopening a project requires the engine to confirm its ports again. Reported ports appear first in the node's lists, in engine order, followed by missing ports in their previous order.

For example, if a synth was connected to an effect whose input is now missing, that connection remains saved. When publishing the graph, the engine excludes it because both ports must be available for a connection to carry data. If the input returns, a later publication includes the connection again. Explicitly deleting a node or connection still removes it from the project.

The engine collects usable connections once during graph compilation. It uses them to determine processing order, allocate buffers and build data transfers between processors. The audio thread receives the compiled result and does not check saved connections for availability during playback.

Device rack connections are generated from device order and each device's default-port references. `DeviceController.rebuildTrackDeviceRouting` removes and recreates all of those generated connections, using cached ports even when they are unavailable. In the synth/effect example, rebuilding still connects the synth to the effect's cached input; it does not bypass the effect because the input is missing. The new connections have new IDs, and graph compilation decides whether they are usable.

Project files store the graph's connections and each port's list of connection IDs. Graph mutation methods update both together. `fromJson` reads those records as stored, assuming they are consistent.

## Project file compatibility

Loading a file saved by an older Anthem version requires a migration before constructing the model. The file reader calls [`migrateProjectJson`](../../lib/logic/project_file/migrations/migrate_project_json.dart) to bring the JSON into the current format. Model `fromJson` methods then read that format without converting older schemas.

The `prealpha.2` migration preserves the old parameter defaults as project reset values and moves visual baselines into `ParameterPresentationModel`. For native processors, it clears the old factory defaults so the engine can supply them during initialization. Existing parameter values are preserved.

## Pre-calculating processing steps

The processing graph is stored in the main thread and compiled into a set of parallelizable processing instructions. When the graph topology is updated, these instructions are recompiled and pushed to the audio thread, at which point the audio thread releases its old instructions and allows them to be deallocated by the main thread.

This is done for two reasons. First, it is non-trivial to traverse this graph. Pre-computing the processing instructions on the main thread saves the audio thread a lot of work. Second, pre-processing these steps opens the door to a fully generic multithreaded solution to audio processing in the future.

## Plugin delay compensation

Plugin delay compensation (PDC) is a feature that allows processing delay in plugins to be corrected by the DAW. Some types of effects, such as EQ, filters and multiband processors, introduce delay into the signal by necessity due to how they perform their processing.

For example, if an audio engineer wants to mix the dry and wet signals of a plugin that introduces delay, the mixed signal will contain phasing artifacts due to the mismatched delay. With PDC, these artifacts will not be present.

Anthem's processing graph does not yet support this.

## Audio

Nodes in the processing graph can generate and consume audio streams. One audio output can go to multiple inputs, and multiple outputs can go to the same input. When multiple audio streams are routed into the same port, they are summed together additively before being given to the corresponding processor to process.

Consider the following graph:

```
 ________________       ____________________________
| SourceNode1    |     | Processor1                 |
|   AudioOutput1----.----AudioInput1   AudioOutput1--- ...
|________________|  |  |____________________________|
                    |
 ________________   |
| SourceNode2    |  |
|   AudioOutput1----*
|________________|
```

Each input port (in this case, just a single input) contains a buffer that is the same length as the block size, plus (in the future) an amount to account for any plugin delay compensation that is needed.

The compiler will produce the following steps for this graph:

1. Write zeros to the `AudioInput1` buffer on `Processor1`
2. Run the process method on `SourceNode1`, which will generate an output on its `AudioOutput1` buffer
3. Add the result of `SourceNode1`'s `AudioOutput1` buffer to the `AudioInput1` buffer on `Processor1`, and write this result back to the `AudioInput1` buffer
4. Same as step 2, but for `SourceNode2`
5. Same as step 3, but for `SourceNode2`

## Control values

Control values function in a very similar way to audio, in that they are represented as audio-rate streams of floating point values. There are, however, a few key differences:

1. Control values are always represented as a floating point between 0 and 1. This should represent the full parameter range, and there should not be any values beyond this range.

2. Control values are not summed additively. If a control input port has multiple connections, the most recent connection takes priority.

### Parameters

In Anthem, all control inputs on nodes also function as parameters. Parameters augment control input ports by allowing the port to be given a constant numerical value to use instead of control input.

If a control input port has a connection, the control values that come through on that connection will always override the static parameter value. Otherwise, the control input will take on the static value provided through the parameter.

During playback, if the static value on a port is changed, it will override any connection value until playback is stopped and starts again.

## Events

Similar to the above data types, processors in Anthem can receive and output events. The most common of these events are note events. Notes coming from the sequencer may be sent directly to an instrument, or they may be transformed by another processor first.

<!-- ## Unique challenges -->

<!-- Must the graph always be acyclic? It seems good to do this for audio, but what about the output of a peak controller? -->
