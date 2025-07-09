# Communication Between UI and Engine

Anthem’s UI and engine each run in their own process—Flutter/Dart for the interface, and C++/JUCE for audio processing—and communicate over a local TCP socket. Messages use a request–response pattern with unique IDs, so a “request” (from UI to engine) pairs with a matching “response” (from engine to UI), though some requests have no response and some responses come through as unsolicited events.

The messages are defined as classes in Dart. Anthem’s code generator inspects these Dart classes to automatically generate the corresponding C++ structs and serialization code, ensuring type-safe, two-way data flow from a single source of truth and with minimal boilerplate.

The example below walks through adding a new request and response to show how Anthem's IPC system works.

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
import 'package:anthem_codegen/include/annotations.dart';

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

# We need to clean the codegen output. This is because the code generator is
# currently unable to detect when the codegen for messages.dart needs to be
# rebuilt, and cleaning the codegen output forces these files to be
# regenerated. These files take an additional 20 to 30 seconds to produce, so
# it's good to skip them if possible.
dart run :cli codegen clean --root-only -y

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
