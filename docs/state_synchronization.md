# State Synchronization

## The problem

Anthem has two primary components: a UI written in Dart with Flutter, and an engine written in C++ with JUCE. These two components run in separate processes and communicate with each other over a local TCP socket. See [Communication Between UI and Engine](communication_between_ui_and_engine.md) for more info about this.

This architecture poses a significant problem for the application, in that both components need access to the same state. Both components have local state that they do not share with the other, but both the UI and the engine need full or nearly full access to the content of the in-memory project file, and need to be able to observe when it changes.

The naive approach would have a UI model and an engine model, and manual code to synchronize the two; or, it would have an engine model which is abstracted with an API that is called via RPC, and the UI would be responsible for using this API to keep the engine updated when the UI model changes.

The issue with the naive approaches is that the UI's project model has a high degree of complexity, and the engine needs full access to all of this data. This means that, for each item in the UI's project model, we need to add at least three additional code constructs: an item in an engine model, a set of RPC commands to update the engine model, and a set of correct calls to these RPC commands whenever something changes in the UI. This has a few key issues:

- This adds a significant amount of complexity for each item in the project model. The engine model change and new RPC calls would be verbose but simple; however, the real complexity comes with the need for correct calls to the relevant engine APIs whenever something changes in the UI. Most things in the project model can be changed in a number of different ways.

  For example, let's say we add a new instrument to the engine's project model, along with any necessary supporting devices (gain, pan, etc.) and audio graph connections. All of these changes to the UI model would need to also be applied to the engine model in each of the following cases: adding a generator, undoing the removal of a generator, and loading a project file. While it is easy to share code between the first two, it is impractical for the last.

- Aside from some render caching for the piano roll and arranger, all side-effects in the Dart model are handled by observing change events that are produced automatically, with no developer effort. This is good, and means that, if you update the model, you don't have to worry about remembering to also update some other thing. Both naive approaches above violate this at all levels in the model, and so would significantly harm maintainability.

- The amount of code for modelling a given feature in the project is highly complex, but also highly predictable. This makes it essentially boilerplate. We really just want the engine to have its own view into the project, so we want to mirror everything in the project model one-to-one in both the engine and UI. The added complexity above is heavy, and so means a lot of boilerplate for each new model item. But, because it is both complex and manually defined, it is highly error-prone. This also results in a significant harm to maintainability and a significant increase in the possible defect surface, as every possible item in the model has the potential to be synced incorrectly.

## The solution

Anthem addresses this problem by introducing a system for automatically generating the C++ engine model from the Dart UI model, and generating code to automatically synchronize the two models. This entirely eliminates the boilerplate for adding model items, and ensures that every change to the UI model continues to produce the correct side-effects automatically.

This system, the implementation of which lives in the `codegen` folder, has the following features:

- Custom code-generated JSON serialization and deserialization, similar to `json_serializable`. This allows us to tweak the JSON output in a simpler way to match any changes needed for the C++ side, and also allows us to avoid writing complex and hard-to-read custom serialization and deserialization routines every time we use a MobX observable collection, something that is necessary when using `json_serializable`.
- Support for generating structs in C++ that match classes in Dart, and for deserializing to them via `reflect-cpp`.
- Automatic one-way (UI to engine) model synchronization over IPC.
- The ability for developers to define "behavior" classes in C++ that inherit from the base generated classes, and therefore are created and destroyed automatically when the associated model items are created and destroyed.

A great example of this system is the tone generator. This processor is defined as a model in Dart with shared configuration attributes (just a single `nodeId` field as of this writing, but this is used in both the UI and engine), and an implementation file in the engine defines the actual DSP. Everything else is handled by code generation.

You can get a node with `ToneGeneratorProcessorModel.getNode()` and add it to the processing graph in Dart along with connections, and the engine will receive these updates automatically and even create an instance of the implementation class. Then you just need to tell the engine to compile the processing graph (an implementation detail, unrelated to and not a limitation of the modelling system), and the tone generator will start playing sound in the configuration specified by the UI's processing graph model.

The files mentioned above are:
- [`lib/model/processing_graph/processors/tone_generator.dart`](../lib/model/processing_graph/processors/tone_generator.dart)
- [`engine/src/modules/processors/tone_generator.h`](../engine/src/modules/processors/tone_generator.h)
- [`engine/src/modules/processors/tone_generator.cpp`](../engine/src/modules/processors/tone_generator.cpp)
