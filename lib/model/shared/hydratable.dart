/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:flutter/foundation.dart';

/// ## Context
///
/// Deserialization from project files is handled using the `json_serializable`
/// library. This saves a lot of boilerplate code, but a limitation of the
/// approach is that some object properties (the state change stream controller
/// in `ProjectModel`, for example) cannot be serialized and so are not
/// recreated when the model is deserialized. In addition, some models contain
/// convenience references to other model items which they do not own, and as
/// such are not serialized - for example, a `ClipModel` has a reference to a
/// `PatternModel` for convenience.
///
/// The solution to this is to separate model construction into two steps: a
/// construction step and a hydration step. The construction step is run
/// either during deserialization by `json_serializable`'s auto-generated model
/// factory, or explicitly by (usually) a `Command`. The hydration step must be
/// run immediately after. `ProjectModel` has a hydrate function that
/// recursively hydrates the whole model, and is must be run after the project
/// is deserialized. In all other cases, constructed models must be hydrated
/// immediately after construction.
///
/// ## Description
///
/// This class exists to make it easier to track issues caused by not hydrating
/// models after constructing them. It is meant to be used as a base class.
///
/// This class does two things:
///   1. It provides an `isHydrated` flag, which should be overridden by the
///      consuming class.
///   2. On construction, it asynchronously schedules some code to run, which
///      will be run after the class is constructed and the current batch of
///      work is completed. This means it should also be run after any
///      immediate `hydrate()` calls. This code checks if the `isHydrated`
///      flag is true, and if not it throws an exception.
///
/// ## Example
///
/// ```dart
/// class SomeModel extends Hydratable {
///   // ...
///
///   @JsonKey(ignore: true)
///   String? _someValue;
///
///   String get someValue {
///     return _someValue!;
///   }
///
///   SomeModel({/* ... */}) : super();
///
///   SomeModel.create({required string someValue, /* ... */}) : super() {
///     this.hydrate(someValue)
///   }
///
///   void hydrate(String someValue) {
///     _someValue = someValue;
///     isHydrated = true;
///   }
/// }
///
/// class SomeParentModel extends Hydratable {
///   // ...
///
///   SomeChildModel someChildModel;
///
///   hydrate() {
///     // Parents should always hydrate children in their hydrate() functions
///     someChildModel.hydrate();
///     isHydrated = true;
///   }
/// }
///
/// // Good - the .create() constructor calls hydrate() by convention
/// final model = SomeModel.create("my value");
///
/// // Not recommended - prefer MyModel.create() constructor over MyModel()..hydrate()
/// final model = SomeModel()..hydrate("my value");
///
/// // Bad
/// final model = SomeModel();
/// // ... forgot to call model.hydrate();
/// // When running in debug mode, this will cause an exception
/// ```
class Hydratable {
  bool isHydrated = false;

  /// Checks that isHydrated is true after construction. It is expected that the
  /// the inheriting class will set this flag in its `hydrate()` function. This
  /// base class exists to make it easy to find missing `hydrate()` calls in
  /// consuming code.
  Hydratable() {
    // Only run this check in debug mode
    if (kDebugMode) {
      final stackTrace = StackTrace.current;

      void check() async {
        if (!isHydrated) {
          Error.throwWithStackTrace(
              Exception(_getHydrationError()), stackTrace);
        }
      }

      Future.delayed(const Duration(seconds: 0), check);
    }
  }

  String _getHydrationError() =>
      "$runtimeType was not hydrated after being constructed. See lib/model/shared/hydratable.dart for more info.";
}
