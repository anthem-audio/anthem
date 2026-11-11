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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (kIsWeb) {
    final originalReporter = reportTestException;
    reportTestException = (details, description) {
      // Flutter's browser backend otherwise only reports "See exception logs
      // above" to the host. Send the actual failure through the test zone so
      // it appears in console output and the JSON event log.
      Zone.current.print(details.toString());
      originalReporter(details, description);
    };
  }
  await testMain();
}
