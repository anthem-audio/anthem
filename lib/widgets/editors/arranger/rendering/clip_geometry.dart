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

import 'package:anthem/widgets/editors/arranger/rendering/clip_title_text.dart';

/// How far clips paint beyond their row content on each vertical edge.
const clipVerticalPaintOvershoot = 1.0;

const _automationTopPadding = clipTitleHeight + 2.0;
const _automationBottomPadding = 2.0;

typedef VerticalPaintBounds = ({double top, double bottom});

VerticalPaintBounds clipPaintVerticalBoundsForRow({
  required double rowTop,
  required double rowHeight,
}) {
  final top = rowTop - clipVerticalPaintOvershoot;
  return (top: top, bottom: top + rowHeight + clipVerticalPaintOvershoot * 2);
}

VerticalPaintBounds automationContentVerticalBoundsForClip({
  required double clipTop,
  required double clipHeight,
}) {
  return (
    top: clipTop + _automationTopPadding,
    bottom: clipTop + clipHeight - _automationBottomPadding,
  );
}

VerticalPaintBounds automationContentVerticalBoundsForRow({
  required double rowTop,
  required double rowHeight,
}) {
  final clipBounds = clipPaintVerticalBoundsForRow(
    rowTop: rowTop,
    rowHeight: rowHeight,
  );

  return automationContentVerticalBoundsForClip(
    clipTop: clipBounds.top,
    clipHeight: clipBounds.bottom - clipBounds.top,
  );
}
