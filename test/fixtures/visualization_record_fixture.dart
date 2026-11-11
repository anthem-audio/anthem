/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:typed_data';

// Kept in sync with the C++ golden file by visualization_record_fixture_test.
// An in-memory fixture lets the same decoder tests run on VM, JS, and WASM.
const visualizationRecordFixtureHex =
    '4149563101000000070000000900000000000000000000000070e740140000000000000002000000040000000000000002000000642dcea90a0000000000000000000000000000801400000000000000000000000000f83f010000000100000002000000690a00000000000000f9ffffffffffffff1400000000000000ffffffffffff1f00';

Uint8List visualizationRecordFixture() => Uint8List.fromList([
  for (var i = 0; i < visualizationRecordFixtureHex.length; i += 2)
    int.parse(visualizationRecordFixtureHex.substring(i, i + 2), radix: 16),
]);
