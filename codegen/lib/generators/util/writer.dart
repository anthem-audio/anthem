/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

/// A utility class for writing code to a string.
///
/// This class is used by the code generators to write code to a string, and has
/// utility methods for managing whitespace.
class Writer {
  var result = StringBuffer();
  var whitespace = '';
  var _generatedIdentifierCount = 0;

  void incrementWhitespace() {
    whitespace += '  ';
  }

  void decrementWhitespace() {
    whitespace = whitespace.substring(2);
  }

  void writeLine([String? line]) {
    if (line == '') {
      result.writeln();
      return;
    }

    result.writeln('$whitespace${line ?? ''}');
  }

  /// Returns a generator-owned identifier that cannot collide with model field
  /// names or other user-defined symbols in emitted code.
  String nextIdentifier(String stem) {
    final identifierIndex = _generatedIdentifierCount++;

    if (stem.isEmpty) {
      return 'anthemCodegen$identifierIndex';
    }

    if (!_isLowerCamelCase(stem)) {
      throw ArgumentError.value(
        stem,
        'stem',
        'Expected a lowerCamelCase identifier stem.',
      );
    }

    return 'anthemCodegen${stem[0].toUpperCase()}${stem.substring(1)}$identifierIndex';
  }
}

bool _isLowerCamelCase(String value) {
  return RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(value);
}
