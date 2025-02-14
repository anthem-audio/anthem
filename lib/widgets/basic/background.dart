/*
  Copyright (C) 2021 Joshua Wade

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
import 'package:provider/provider.dart';

import '../../theme.dart';

enum BackgroundType { dark, light }

// Renders a container with the specified background type, and supplies that
// type to children via a provider.

class Background extends StatelessWidget {
  final BackgroundType type;
  final Widget? child;
  final Border? border;
  final BorderRadius? borderRadius;

  const Background({
    super.key,
    required this.type,
    this.child,
    this.border,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Provider<BackgroundType>(
      create: (context) => type,
      child: Container(
        decoration: BoxDecoration(
          color:
              type == BackgroundType.dark
                  ? Theme.panel.main
                  : Theme.panel.accent,
          border: border,
          borderRadius: borderRadius,
        ),
        child: child,
      ),
    );
  }
}
