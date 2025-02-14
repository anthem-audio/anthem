/*
  Copyright (C) 2025 Joshua Wade

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

import 'package:anthem/commands/command.dart';
import 'package:anthem/model/project.dart';

/// A command to set the tempo of the project sequence.
///
/// newRawTempo and oldRawTempo are stored as fixed point numbers with 2 decimal
/// places. For example, 120 BPM would be stored as 12000.
class SetTempoCommand extends Command {
  final int newRawTempo;
  final int oldRawTempo;

  SetTempoCommand({required this.newRawTempo, required this.oldRawTempo});

  @override
  void execute(ProjectModel project) {
    project.sequence.beatsPerMinuteRaw = newRawTempo;
  }

  @override
  void rollback(ProjectModel project) {
    project.sequence.beatsPerMinuteRaw = oldRawTempo;
  }
}

/// A command to set the time signature of the project sequence.
///
/// Numerator and denominator are the numerator and denominator of the time
/// signature.
class SetTimeSignatureCommand extends Command {
  final int newNumerator;
  final int newDenominator;

  final int oldNumerator;
  final int oldDenominator;

  SetTimeSignatureCommand({
    required this.newNumerator,
    required this.newDenominator,
    required this.oldNumerator,
    required this.oldDenominator,
  });

  @override
  void execute(ProjectModel project) {
    project.sequence.defaultTimeSignature.numerator = newNumerator;
    project.sequence.defaultTimeSignature.denominator = newDenominator;
  }

  @override
  void rollback(ProjectModel project) {
    project.sequence.defaultTimeSignature.numerator = oldNumerator;
    project.sequence.defaultTimeSignature.denominator = oldDenominator;
  }
}
