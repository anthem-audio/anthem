## Introduction

Anthem is a modern, multi-workflow digital audio workstation.

Anthem is built with maintainability in mind. The goal is to build a beautiful and capable DAW that can be developed by and maintained by a group of volunteers. This has influenced a number of architectural decisions, including:
- Anthem's UI is built with Flutter, which gives us two key advantages. First, Flutter has a fantastic and time-saving developer experience, which goes a long way to enable rapid development. Features like hot-reload significantly improve iteration time, and Flutter's mature platform allows us to focus on solving the problems we actually care about. Flutter is also an excellent abstraction for building UIs, and its use of the Dart language allows us to mix and match helper libraries that work for our use-cases, such as MobX. Second, Flutter is fast by default. Flutter takes care of a huge number of optimizations that we don't have to think about, and it provides tools for us to optimize anything that's left.
- The Anthem engine uses Tracktion Engine at its core. In some sense, DAWs are a solved problem, similar to UI. This doesn't mean there is no room for innovation in the space, but Anthem doesn't need innovative audio processing features to have a place in the landscape of open-source DAWs. Instead, Anthem's strength is beautiful UI design and strong usability, and our design decisions are in service of these strengths.

## Architecture

Anthem has two main components, the UI and the engine. These components live in two separate processes. The UI process is where most of our logic happens, and the engine process wraps Tracktion Engine and controls it based on commands from the UI. These processes communicate with each other using messages encoded with Flatbuffers.

When the UI wants to do something, it will send a message to the engine. A typical round-trip for a message could look like this:
1. A function in the Dart API for the engine is called, such as `Engine.projectApi.addArrangement()`, which returns a `Future<int>`. The integer it returns represents a pointer to the corresponding Tracktion `Edit` object in the memory space of the engine process.
2. The `addArrangement()` function constructs an `AddArrangement` message with Flatbuffers and sends it to the engine via the engine connector. The engine connector (EngineConnector class in Dart, which has `dart:ffi` bindings to a C++ DLL) has a `message_queue` from `Boost.Interprocess` that it uses to send the bytes from the Flatbuffers message to the engine process.
3. The engine process has an event loop. The main thread of the engine will block while waiting for new messages on the message queue, and will handle messages as they come in. When the engine receives the AddArrangement message, it creates a new `Edit`, gets its pointer, and sends the pointer back to the UI as an integer. This pointer is stored in the UI and is used when manipulating this `Edit`.
4. The UI receives the reply from the engine. It deocdes the reply and pulls out the pointer, which it uses to complete the future.
