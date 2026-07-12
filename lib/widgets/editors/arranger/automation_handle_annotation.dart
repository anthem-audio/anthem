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

import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';

enum AutomationHandleKind { tensionHandle, point }

class AutomationHandleAnnotation {
  final Id clipId;
  final AutomationHandleKind kind;
  final int pointIndex;
  final Id pointId;
  final Offset center;

  const AutomationHandleAnnotation({
    required this.clipId,
    required this.kind,
    required this.pointIndex,
    required this.pointId,
    required this.center,
  });
}

typedef AutomationHandleAnnotationSet =
    CanvasAnnotationSet<AutomationHandleAnnotation>;
