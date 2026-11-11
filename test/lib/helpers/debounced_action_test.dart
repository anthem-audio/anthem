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

import 'package:anthem/helpers/debounced_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'microtask actions coalesce requests and can schedule another run',
    () async {
      var runs = 0;
      late final MicrotaskDebouncedAction action;
      action = MicrotaskDebouncedAction(() {
        runs++;
        if (runs == 1) action.execute();
      });

      action.execute();
      action.execute();
      expect(runs, 0);

      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);
    },
  );

  test('microtask actions can run again after a callback throws', () async {
    final failure = StateError('Action failed');
    final reportedError = Completer<Object>();
    var runs = 0;
    final action = MicrotaskDebouncedAction(() {
      runs++;
      if (runs == 1) throw failure;
    });

    runZonedGuarded(action.execute, (error, stack) {
      reportedError.complete(error);
    });
    expect(await reportedError.future, same(failure));

    action.execute();
    await Future<void>.delayed(Duration.zero);
    expect(runs, 2);
  });
}
