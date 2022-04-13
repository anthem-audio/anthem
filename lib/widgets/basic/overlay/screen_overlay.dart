/*
  Copyright (C) 2022 Joshua Wade

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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';

import 'screen_overlay_cubit.dart';

/// A `Stack` that is always rendered above the rest of the app.
/// `ScreenOverlayCubit` provides an API that should be accessible from
/// anywhere within Anthem, as long as it lives beneath the `ScreenOverlay`.
///
/// Example usage:
/// ```dart
/// Provider.of<ScreenOverlayCubit>().add(/* ... */);
/// ```
class ScreenOverlay extends StatelessWidget {
  final Widget child;

  const ScreenOverlay({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScreenOverlayCubit, ScreenOverlayState>(
      builder: (context, state) {
        final cubit = BlocProvider.of<ScreenOverlayCubit>(context);

        final stackChildren = <Widget?>[
              Positioned.fill(
                child: child,
              ),
              state.widgets.isNotEmpty
                  ? Positioned.fill(
                      child: Listener(
                        onPointerUp: (event) {
                          cubit.clear();
                        },
                        child: Container(color: const Color(0x00000000)),
                      ),
                    )
                  : null,
            ].whereNotNull().toList() +
            state.widgets;

        return Stack(
          children: stackChildren,
        );
      },
    );
  }
}
