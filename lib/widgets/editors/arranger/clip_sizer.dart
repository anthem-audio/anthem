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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:anthem/widgets/basic/clip/clip.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

/// Allows us to perform layout on specific clips when their pattern size
/// changes without rebuilding all clips in the arranger
class ClipSizer extends StatelessObserverWidget {
  final Clip child;
  final ID clipID;
  final ID arrangementID;
  final double timeViewStart;
  final double timeViewEnd;
  final double editorWidth;

  const ClipSizer({
    Key? key,
    required this.child,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.editorWidth,
    required this.clipID,
    required this.arrangementID,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final projectModel = Provider.of<ProjectModel>(context);
    final clipModel =
        projectModel.song.arrangements[arrangementID]!.clips[clipID]!;

    final width = timeToPixels(
      timeViewStart: 0,
      timeViewEnd: timeViewEnd - timeViewStart,
      viewPixelWidth: editorWidth,
      time: clipModel.width.toDouble(),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
      ),
      child: child,
    );
  }
}
