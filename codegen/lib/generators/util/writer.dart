/*
  Copyright (C) 2024 Joshua Wade

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
  var result = '';
  var whitespace = '';

  void incrementWhitespace() {
    whitespace += '  ';
  }

  void decrementWhitespace() {
    whitespace = whitespace.substring(2);
  }

  void writeLine([String? line]) {
    if (line == '') {
      result += '\n';
      return;
    }

    result += '$whitespace${line ?? ''}\n';
  }

  void write(String line) {
    if (result.isEmpty || result.substring(result.length - 1) == '\n') {
      result += whitespace;
    }
    result += line;
  }
}