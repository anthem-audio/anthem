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

import 'dart:async';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

class AnthemModelGenerator extends Generator {
  final BuilderOptions options;

  AnthemModelGenerator(this.options);

  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    var result = '';

    for (final libraryClass in library.classes) {
      final annotation = libraryClass.metadata
          .where(
            (annotation) => annotation.element?.displayName == 'AnthemModel',
          )
          .firstOrNull;

      if (annotation != null) {
        result += '// annotation found\n';
      }

      for (final metadata in libraryClass.metadata) {
        result += '// found: ${metadata.element?.displayName ?? ''}\n';
      }
    }

    return result;
  }
}
