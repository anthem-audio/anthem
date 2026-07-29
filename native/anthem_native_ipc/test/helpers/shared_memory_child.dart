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

import 'dart:io';

import 'package:anthem_native_ipc/anthem_native_ipc.dart';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln('Expected a shared memory identifier and size.');
    exitCode = 2;
    return;
  }

  final region = SharedMemoryRegion.open(
    identifier: arguments[0],
    size: int.parse(arguments[1]),
  );

  try {
    if (region.bytes[0] != 37) {
      stderr.writeln('The child process did not observe the parent value.');
      exitCode = 3;
      return;
    }

    region.bytes[1] = 91;
  } finally {
    region.close();
  }
}
