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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';

/// Explicitly reads `part` files for [buildStep.inputId] so changes to those
/// files invalidate the build step.
Future<void> trackLibraryPartInputs(BuildStep buildStep) async {
  final libraryUnit = await buildStep.resolver.compilationUnitFor(
    buildStep.inputId,
    allowSyntaxErrors: true,
  );

  final trackedAssets = <AssetId>{};

  for (final directive in libraryUnit.directives.whereType<PartDirective>()) {
    final uriValue = directive.uri.stringValue;
    if (uriValue == null) continue;

    final assetId = AssetId.resolve(
      Uri.parse(uriValue),
      from: buildStep.inputId,
    );

    if (!trackedAssets.add(assetId)) continue;
    if (!await buildStep.canRead(assetId)) continue;

    await buildStep.readAsString(assetId);
  }
}
