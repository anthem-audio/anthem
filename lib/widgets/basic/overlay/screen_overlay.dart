/*
  Copyright (C) 2022 - 2023 Joshua Wade

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

import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

/// A `Stack` that is always rendered above the rest of the app.
/// `ScreenOverlayCubit` provides an API that should be accessible from
/// anywhere within Anthem, as long as it lives beneath the `ScreenOverlay`.
///
/// Example usage:
/// ```dart
/// Provider.of<ScreenOverlayCubit>().add(/* ... */);
/// ```
class ScreenOverlay extends StatelessObserverWidget {
  final Widget child;

  final ScreenOverlayViewModel viewModel = ScreenOverlayViewModel();
  late final ScreenOverlayController controller;

  ScreenOverlay({super.key, required this.child}) {
    controller = ScreenOverlayController(viewModel: viewModel);
  }

  @override
  Widget build(BuildContext context) {
    final stackChildren =
        <Widget?>[
          Positioned.fill(child: child),
          viewModel.entries.isNotEmpty
              ? Positioned.fill(
                  child: Listener(
                    onPointerUp: (event) {
                      controller.clear();
                    },
                    onPointerCancel: (event) {
                      controller.clear();
                    },
                    child: Container(color: const Color(0x00000000)),
                  ),
                )
              : null,
        ].nonNulls.toList() +
        // state.entries is a Map<ID, ScreenOverlayEntry>
        // state.entries.entries is a Iterable<MapEntry<String, ScreenOverlayEntry>>
        viewModel.entries.entries
            .map<Widget>(
              (mapEntry) => mapEntry.value.builder(context, mapEntry.key),
            )
            .toList();

    return Provider.value(
      value: viewModel,
      child: Provider.value(
        value: controller,
        child: Stack(children: stackChildren),
      ),
    );
  }
}
