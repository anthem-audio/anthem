# Communication Between UI and Engine

Anthem’s UI and engine each run in their own process—Flutter/Dart for the interface, and C++/JUCE for audio processing—and communicate over a local TCP socket. Messages use a request–response pattern with unique IDs, so a “request” (from UI to engine) pairs with a matching “response” (from engine to UI), though some requests have no response and some responses come through as unsolicited events.

The messages are defined as classes in Dart. Anthem’s code generator inspects these Dart classes to automatically generate the corresponding C++ structs and serialization code, ensuring type-safe, two-way data flow from a single source of truth and with minimal boilerplate.

The example below walks through adding a new request and response to show how Anthem's IPC system works.

## Visualization transport

Commands, replies, subscription changes, and update-interval requests remain on
the reliable JSON channel (TCP on desktop, the existing byte rings on web).
Visualization batches use a separate bounded SPSC record ring. Its single writer
is the JUCE message thread, and its single reader is the Dart UI isolate.
Encoding and publishing never happen on the audio thread.

`Engine` owns a `VisualizationComms` instance, which encapsulates the channel's
storage, ring endpoints, and platform-specific initialization. The
`VisualizationBroker` manages providers and subscriptions, and its record
publisher handles encoding and batching. The broker borrows the writer from
`VisualizationComms`; the web entry points borrow its reader. The endpoints are
destroyed before their backing storage when the engine is destroyed.

The desktop UI initializes a shared-memory mapping before starting the engine.
The engine attaches its writer and reports initialization errors through the
existing ready-check handshake. The UI unlinks the mapping's identifier after
that handshake and retains its mapping until the reader is closed. Web uses the
same C++ ring implementation in shared WebAssembly memory; exported functions
perform acquire/release and expose queue occupancy. Both allocate 16 MiB of usable
data plus 128 bytes of cursor storage. Usable ring capacity is a power of two so
32-bit cursor rollover preserves physical offsets.

### Record format, version 1

All numbers are little-endian. Fields are encoded individually, without C++
struct padding. Each record has this 40-byte header:

| Offset | Field | Encoding |
| --- | --- | --- |
| 0 | Magic, `AIV1` | uint32, `0x31564941` |
| 4 | Format version | uint32, `1` |
| 8 | Publication attempt sequence | uint32, wrapping |
| 12 | Audio processing configuration generation | uint64 |
| 20 | Sample rate | IEEE 754 float64 |
| 28 | Newest sample timestamp in this batch | int64 |
| 36 | Item count | uint32 |

Each item begins with three uint32 fields: UTF-8 ID byte length, value type
(0 = double, 1 = integer), and sample count, followed by the ID bytes. The former
string value type (2) is unsupported; subscription IDs remain UTF-8 strings.
Each sample occupies 16 bytes: an int64 timestamp followed by a float64 or int64
value. Timestamps use the engine's sample counter, are nonnegative, and are
ordered within each item. The numeric encodings and type IDs are unchanged.

Records are limited to 1 MiB, IDs to 4096 bytes, and each item to 2048 samples.
Sample rates must be finite, positive, and at most 1 MHz. JavaScript Dart rejects
integers outside its exact 53-bit range; native and WebAssembly Dart use 64-bit
integer accessors.
The decoder validates counts, bounds, value types, UTF-8, timestamp ordering,
duplicate IDs, and trailing bytes. Incompatible or malformed records stop the
connector rather than letting it continue with an uninterpretable transport.
The common fixture in `test/fixtures/visualization_record_v1.hex` verifies the
C++ encoder and Dart decoder against the same bytes.

### Freshness and ownership

A full ring rejects the entire new record without blocking or modifying the
reader cursor. The publisher retains one coalesced pending update, merges newer
values, trims history to the most recent 250 ms (retaining the final value of slow
streams), and retries even when providers have no new data. If a batch exceeds
the record limit, it retains numeric peaks and final values before dropping
items that still cannot fit. Provider replacement, subscription changes, audio
configuration changes, and render suppression discard pending state.

Dart polls the desktop ring every 8 ms. Web polls on Flutter frames, with a timer
fallback when frames are absent. Each pass has a 256-record / 2 ms budget, with
a yielded continuation when necessary; a single decode is bounded by the record
size limit. A record is decoded into owned Dart values before release, including
on errors. Ring-backed views must never escape acquisition into subscriptions.
The web reader obtains the current Emscripten heap for each acquisition, so heap
growth does not reuse a stale view.

The consumer coalesces recent samples before notifying the visualization
provider. It detects sequence gaps, session changes, and pauses longer than
250 ms. On recovery, timing estimates and old adaptive history are reset, while
UI overrides and slowly changing unbuffered latest values survive. Adaptive
render cursors also fast-forward if they fall more than 250 ms beyond their
target delay behind the newest sample. Ordinary jitter still uses adaptive
buffering, and meter peaks in the retained history remain available.

Publisher counters track published records, rejected writes, and oversized
updates. Consumer counters track records/bytes read, skipped records/samples,
discontinuities, queue byte high-water, and maximum drain duration. These are
available for debugger inspection without per-message logging. Publish intervals
are validated and capped at 240 Hz; the UI requests the refresh rate of its own
display. Stop, startup cancellation, process exit, and disposal close the reader
before releasing storage and cancel poll continuations, timers, and web tickers.

These changes affect runtime IPC only and do not change project files.

### Transport verification

Engine unit tests cover cursor rollover, concurrent access, full-ring retry,
provider removal, and peak retention when compacting oversized records. Native
IPC package tests also exercise a child process and reader/mapping cleanup. The
desktop engine integration test sends the common fixture through the actual
writer and restarts the process with the same engine ID, without an audio device.

The web CI job tests the browser reader and decoder with both Dart compilers:

```bash
dart run anthem:cli flutter_test --web
```

The browser tests cover zero-copy acquisition, release on invalid views, heap
replacement, disposal, and owned decoded values. Dart transport tests cover
malformed records, bounded burst draining, recent peaks, sequence rollover,
pauses, and audio generation changes.

See [Testing](../testing.md) for browser suite selection and widget test coverage.

## Adding a new request and response

`messages.dart` in `lib/engine_api/messages` contains base `Request` and `Response` classes. Note that these names merely indicate the direction of the message flow, in that requests are always sent from the UI to the engine and responses are always sent from the engine to the UI. Some requests do not expect a response, and some responses are unprompted.

Messages are defined as subclasses of either `Request` or `Response`. Since both base classes are sealed, the sub-classes must be in a `part` file - you can see examples of these at the top of `messages.dart`:

```dart
part 'model_sync.dart';
part 'processing_graph.dart';
part 'your_messages_here.dart';
// etc...
```

To illustrate how the messaging system works, this guide outlines the process for adding a new request and response and explains the implementation conventions in both the UI and the engine.

To define a new request and response, start by creating a new file in `lib/engine_api/messages` called `example.dart`:

```dart
part of 'messages.dart';

class AddRequest extends Request {
  /// This named constructor must be present, as the code generator uses this
  /// during deserialization. However, we won't ever deserialize this class
  /// since it's a request. See below for more information on how this is used
  /// in the response case.
  AddRequest.uninitialized();

  /// This is an ordinary constructor, which we will use to create instances of
  /// this class.
  AddRequest({required int id, required this.a, required this.b}) {
    super.id = id;
  }

  // All field types here are valid, as long as they are supported by the code
  // generator. This includes:
  //   - int, double, num, String and bool
  //   - enums, as long as they are tagged with @AnthemEnum
  //   - other classes, as long as they are tagged with @AnthemModel (note that
  //     this works for the application model, but is untested in messages as of
  //     this writing)
  //   - Object, as long as it is tagged with @Union([Type1, Type2, ...]) to
  //     describe the allowed types for the field
  //   - nullable and late fields with the above types
  //   - lists of the above
  //   - maps of the above

  /// The first number to add
  late int a;

  /// The second number to add
  late int b;
}

class AddResponse extends Response {
  /// This constructor must be present. The code-generated deserializer will
  /// call this constructor, and then set the fields on the object that is
  /// created.
  ///
  /// The deserializer will not write to nullable fields if the incoming JSON
  /// does not contain a value for that field. In that case, this constructor
  /// should set the field to null. However, in all other cases, the initial
  /// value of the field does not matter, as it will be overwritten by the
  /// deserializer.
  AddResponse.uninitialized();

  AddResponse({required int id, required this.result}) {
    super.id = id;
  }

  /// The result of the addition
  late int result;
}
```

In `lib/engine_api/messages/messages.dart`, we need a matching `part` declaration, like so:

```dart
import 'package:anthem_codegen/include.dart';

part 'example.dart'; // <-- here, since this list is alphabetically sorted
part 'model_sync.dart';
part 'processing_graph.dart';

part 'messages.g.dart';

// ...
```

This is all the code we need to make our new request and response available to both the UI in Dart, and the engine in C++. The code generator will generate the following for us:
- Dart code to serialize and deserialize both classes
- C++ classes that match the new Dart classes
- A way in C++ to serialize and deserialize the new classes

Next, we will add an async interface on the Dart side, so this new request can be called as a function, like so:

```dart
final result = await engine.exampleApi.add(1, 2);
print(result); // We would expect this to print "3"
```

To do this, we will start by adding a new file called `example_api.dart` in `lib/engine_api/api`, which will contain our new `add()` method. This is just a convention for grouping engine API methods. Our new `add()` method could go in any existing API file, and more methods could be added to our new `example_api.dart` file in the future.

`example_api.dart` will contain the following:

```dart
part of 'package:anthem/engine_api/engine.dart';

class ExampleApi {
  final Engine _engine;

  ExampleApi(this._engine);

  Future<int> add(int a, int b) async {
    final id = _engine._getRequestId();

    final request = AddRequest(
      id: id,
      a: a,
      b: b,
    );

    // The response comes back from this method as the base class Response, so
    // we need to cast it to the correct subclass.
    final response = await _engine._request(request) as AddResponse;

    return response.result;
  }

  // Add more methods here as needed...
}
```

And we will add a matching `part of` declaration in `lib/engine_api/engine.dart`, along with instancing the API as a field in `Engine`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:anthem/engine_api/engine_connector.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter/foundation.dart';

part 'api/example_api.dart'; // <-- here
part 'api/model_sync_api.dart';
part 'api/processing_graph_api.dart';

// ...

class Engine {
  // ...

  late ExampleApi exampleApi; // <-- here
  late ModelSyncApi modelSyncApi;
  late ProcessingGraphApi processingGraphApi;

  // ...

  Engine(this.id, this.project, {this.enginePathOverride}) {
    engineStateStream = _engineStateStreamController.stream;

    exampleApi = ExampleApi(this); // <-- here
    modelSyncApi = ModelSyncApi(this);
    processingGraphApi = ProcessingGraphApi(this);
  }
}
```

`Engine._request()` does the following:

1. Serialize the request to JSON
2. Send the JSON to the engine process
3. Wait for a response from the engine process with the same ID, and
     deserialize it
4. Return the deserialized response

There is also a `Engine._requestNoReply()` method that does the same thing, but does not wait for a response. This must be used for fire-and-forget requests; otherwise, the UI will wait forever for the response, which effectively causes a memory leak.

Now, we just need to handle the message in the engine. We will create two new files, `example_command_handler.h` and `example_command_handler.cpp` in `engine/src/command_handlers`:

`example_command_handler.h`:

```cpp
#pragma once

#include <rfl.hpp>

#include "messages/messages.h"

std::optional<Response> handleExampleCommand(Request& request);
```

`example_command_handler.cpp`:

```cpp
#include "example_command_handler.h"

std::optional<Response> handleExampleCommand(Request& request) {
  // Models on the C++ side are implemented using reflect-cpp. See the
  // reflect-cpp documentation for more information on how the rfl::* types and
  // functions work.
  if (rfl::holds_alternative<AddRequest>(request.variant())) {
    auto& requestAsAdd = rfl::get<AddRequest>(request.variant());

    auto result = requestAsAdd.a + requestAsAdd.b;

    // This is created using C++20 designated initializers. Note that, while
    // this reads well, the order of the fields is dependent on the order that
    // they are declared in the code-generated AddResponse struct.
    auto addResponse = AddResponse {
      .result = result,
      .responseBase = ResponseBase {
        .id = requestAsAdd.requestBase.get().id
      }
    };

    // We return the response. The caller will serialize this and send it back
    // to the UI.
    return std::optional(
      std::move(addResponse)
    );
  }

  // Add more handlers here...

  // If this handler did not handle the request, we just return an empty
  // optional.
  return std::nullopt;
}
```

Then, we modify `CommandMessageListener::handleMessage()` in `main.cpp` to add our new command handler:

```cpp
#include "./command_handlers/example_command_handler.h"

// ...

class CommandMessageListener : public juce::MessageListener
{
public:
  void handleMessage(const juce::Message& message) override {

    // ...

    // Insert this below the other handleSomeCommand() function calls
    auto handleExampleCommandResponse = handleExampleCommand(request);
    if (handleExampleCommandResponse.has_value()) {
      if (response.has_value()) {
        didOverwriteResponse = true;
      }
      response = std::move(handleExampleCommandResponse);
    }

    // ...
  }
};
```

Finally, we will run the code generator and compile the engine:

```bash
# "dart run :cli" runs the script in bin/cli.dart. You can learn more about the
# script with:
dart run :cli -h

# Or:
dart run :cli codegen -h
dart run :cli engine -h

# This runs the code generator. The --root-only option prevents code generation
# for the tests in the codegen folder, which aren't needed to build or run
# Anthem.
dart run :cli codegen generate --root-only

# This builds the engine using CMake.
dart run :cli engine build --debug
```

Now, we can use our new API. As an example, here's a modification to `project.dart` that fires off this request as soon as the engine is started:

```dart
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'Project',
  cppBehaviorClassIncludePath: 'modules/core/project.h',
)
class ProjectModel extends _ProjectModel
    with _$ProjectModel, _$ProjectModelAnthemModelMixin {
  // ...

  void hydrate() {
    // ...

    engine.engineStateStream.listen((state) async { // <-- This wasn't async originally
      // ...

      // Send model state change messages to the engine
      if (state == EngineState.running) {
        _initializeEngine();
        _attachModelChangeListener();

        // Note that the engine for each project lives in the project model. If
        // you need the engine from a different file, you would need to first get
        // the project, then access it via:
        //    (some ProjectModel).engine

        final result = await engine.exampleApi.add(1, 2);
        print('1 + 2: $result');
      }
    });
  }
}
```

This will produce the following output when the engine is started:

```
flutter: 1 + 2: 3
```
