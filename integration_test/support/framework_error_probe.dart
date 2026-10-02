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

import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_session.dart';

/// This deliberately fails. Run explicitly to verify app logging preserves the
/// integration binding's framework exception reporting and the CLI exit code.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testAppScenario('framework exception must fail this probe', (tester) async {
    final session = AppTestSession(tester, name: 'framework-error-probe');
    await session.start();
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('Intentional framework error probe'),
      ),
    );
  });
}
