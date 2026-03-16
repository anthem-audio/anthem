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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';

const _codegenDependencyTrackerZoneKey = #codegenDependencyTracker;

/// Tracks extra inputs that Anthem code generation depends on.
///
/// The generators inspect foreign model classes, enums, and exported/imported
/// libraries while producing code for a single library input. Those files are
/// not always read directly by source_gen, so we explicitly read them here to
/// make build invalidation match the data the generators actually use.
///
/// If we don't do this, then a model that imports and references another model
/// from another file will not invalidate when that model changes.
class CodegenDependencyTracker {
  final BuildStep _buildStep;
  final Set<AssetId> _trackedAssets = <AssetId>{};
  final Set<Element> _trackedElements = <Element>{};
  final Map<AssetId, _TrackedLibraryOptions> _requestedLibraries =
      <AssetId, _TrackedLibraryOptions>{};
  final Map<AssetId, _TrackedLibraryOptions> _processedLibraries =
      <AssetId, _TrackedLibraryOptions>{};

  CodegenDependencyTracker._(this._buildStep);

  static CodegenDependencyTracker? get current {
    return Zone.current[_codegenDependencyTrackerZoneKey]
        as CodegenDependencyTracker?;
  }

  /// Runs a code generation pass with a tracker installed in the current zone.
  ///
  /// The full generator body must run inside this callback because deeper
  /// parsing helpers use [current] to register dependencies without threading a
  /// tracker parameter through every parsing API. After [action] completes, the
  /// tracker flushes all queued assets and libraries by reading them so
  /// `build_runner` records them as real inputs for invalidation.
  static Future<T> run<T>(
    BuildStep buildStep,
    Future<T> Function(CodegenDependencyTracker tracker) action,
  ) async {
    final tracker = CodegenDependencyTracker._(buildStep);

    final result = await runZoned(
      () => action(tracker),
      zoneValues: {_codegenDependencyTrackerZoneKey: tracker},
    );

    await tracker.flush();
    return result;
  }

  void trackAsset(AssetId assetId) {
    _trackedAssets.add(assetId);
  }

  void trackElement(Element? element) {
    if (element == null) return;
    _trackedElements.add(element);
  }

  void trackLibraryAsset(
    AssetId assetId, {
    bool includeDirectImports = false,
    bool includeDirectExports = false,
  }) {
    if (assetId.extension != '.dart') {
      trackAsset(assetId);
      return;
    }

    final options = _TrackedLibraryOptions(
      includeDirectImports: includeDirectImports,
      includeDirectExports: includeDirectExports,
    );

    _requestedLibraries[assetId] =
        (_requestedLibraries[assetId] ?? const _TrackedLibraryOptions()).merge(
          options,
        );
  }

  void trackLibraryUri(
    Uri? uri, {
    bool includeDirectImports = false,
    bool includeDirectExports = false,
  }) {
    if (uri == null || uri.scheme == 'dart') return;

    try {
      trackLibraryAsset(
        AssetId.resolve(uri),
        includeDirectImports: includeDirectImports,
        includeDirectExports: includeDirectExports,
      );
    } on ArgumentError {
      return;
    } on UnsupportedError {
      return;
    }
  }

  Future<void> flush() async {
    while (true) {
      if (_trackedElements.isNotEmpty) {
        final elements = _trackedElements.toList(growable: false);
        _trackedElements.clear();

        for (final element in elements) {
          await _trackQueuedElement(element);
        }

        continue;
      }

      final pendingLibrary = _takePendingLibrary();
      if (pendingLibrary != null) {
        await _trackLibrary(pendingLibrary.assetId, pendingLibrary.options);
        continue;
      }

      break;
    }

    for (final assetId in _trackedAssets) {
      if (!await _buildStep.canRead(assetId)) continue;
      await _buildStep.readAsString(assetId);
    }
  }

  _PendingLibraryTracking? _takePendingLibrary() {
    for (final entry in _requestedLibraries.entries) {
      final assetId = entry.key;
      final requestedOptions = entry.value;
      final processedOptions = _processedLibraries[assetId];

      if (processedOptions != null &&
          processedOptions.covers(requestedOptions)) {
        continue;
      }

      final mergedOptions = (processedOptions ?? const _TrackedLibraryOptions())
          .merge(requestedOptions);

      _processedLibraries[assetId] = mergedOptions;

      return _PendingLibraryTracking(assetId: assetId, options: mergedOptions);
    }

    return null;
  }

  Future<void> _trackQueuedElement(Element element) async {
    final library = element.library;
    if (library != null && library.isInSdk) return;

    try {
      final assetId = await _buildStep.resolver.assetIdForElement(element);
      _trackedAssets.add(assetId);
    } catch (_) {
      // Some dependency elements resolve from summaries. Fall back to the
      // library URI so public package assets can still participate.
    }

    trackLibraryUri(library?.uri);
  }

  Future<void> _trackLibrary(
    AssetId assetId,
    _TrackedLibraryOptions options,
  ) async {
    _trackedAssets.add(assetId);

    if (!await _buildStep.canRead(assetId)) return;

    final libraryUnit = await _buildStep.resolver.compilationUnitFor(
      assetId,
      allowSyntaxErrors: true,
    );

    for (final directive in libraryUnit.directives.whereType<PartDirective>()) {
      final partAssetId = _resolveDirectiveAssetId(
        directive.uri.stringValue,
        assetId,
      );

      if (partAssetId != null) {
        _trackedAssets.add(partAssetId);
      }
    }

    if (options.includeDirectImports) {
      for (final directive
          in libraryUnit.directives.whereType<ImportDirective>()) {
        final importAssetId = _resolveDirectiveAssetId(
          directive.uri.stringValue,
          assetId,
        );

        if (importAssetId != null) {
          trackLibraryAsset(importAssetId);
        }
      }
    }

    if (options.includeDirectExports) {
      for (final directive
          in libraryUnit.directives.whereType<ExportDirective>()) {
        final exportAssetId = _resolveDirectiveAssetId(
          directive.uri.stringValue,
          assetId,
        );

        if (exportAssetId != null) {
          trackLibraryAsset(exportAssetId);
        }
      }
    }
  }

  AssetId? _resolveDirectiveAssetId(String? uriValue, AssetId from) {
    if (uriValue == null) return null;

    final uri = Uri.tryParse(uriValue);
    if (uri == null || uri.scheme == 'dart') return null;

    try {
      return AssetId.resolve(uri, from: from);
    } on ArgumentError {
      return null;
    } on UnsupportedError {
      return null;
    }
  }
}

class _PendingLibraryTracking {
  final AssetId assetId;
  final _TrackedLibraryOptions options;

  const _PendingLibraryTracking({required this.assetId, required this.options});
}

class _TrackedLibraryOptions {
  final bool includeDirectImports;
  final bool includeDirectExports;

  const _TrackedLibraryOptions({
    this.includeDirectImports = false,
    this.includeDirectExports = false,
  });

  _TrackedLibraryOptions merge(_TrackedLibraryOptions other) {
    return _TrackedLibraryOptions(
      includeDirectImports: includeDirectImports || other.includeDirectImports,
      includeDirectExports: includeDirectExports || other.includeDirectExports,
    );
  }

  bool covers(_TrackedLibraryOptions other) {
    return (!other.includeDirectImports || includeDirectImports) &&
        (!other.includeDirectExports || includeDirectExports);
  }
}
