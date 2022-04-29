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

import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:anthem/widgets/basic/clip/clip_cubit.dart';
import 'package:anthem/widgets/basic/clip/clip.dart';

/// Allows us to perform layout on specific clips when their pattern size
/// changes without rebuilding all clips in the arranger
class ClipSizer extends StatelessWidget {
  final Clip child;
  final double timeViewStart;
  final double timeViewEnd;
  final double editorWidth;

  const ClipSizer({
    Key? key,
    required this.child,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.editorWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipCubit, ClipState>(builder: (context, state) {
      final width = timeToPixels(
        timeViewStart: 0,
        timeViewEnd: timeViewEnd - timeViewStart,
        viewPixelWidth: editorWidth,
        time: state.contentWidth.toDouble(),
      );

      return ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
        ),
        child: child,
      );
    });
  }
}
