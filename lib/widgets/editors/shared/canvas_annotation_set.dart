/*
  Copyright (C) 2023 Joshua Wade

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

typedef CanvasAnnotation<T> = ({Rect rect, T metadata});

/// Describes a set of annotations for a canvas frame.
///
/// This class is used to describe where certain items are rendered, which helps
/// us process pointer events. For example, when we draw a frame of the
/// arranger, we can produce a CanvasAnnotationSet which describes where each
/// rendered clip is on screen. Then, when we receive a pointer down event, we
/// can look up in this list to determine if the pointer is over a clip. This is
/// more efficient and less complex than trying to determine this information
/// from the application model when an event occurs.
class CanvasAnnotationSet<T> {
  final List<CanvasAnnotation<T>> _annotations = [];

  /// Clears the annotation set to prepare for the next frame
  void clear() {
    _annotations.clear();
  }

  /// Adds an annotation to the annotation set
  void add({required Rect rect, required T metadata}) {
    _annotations.add((rect: rect, metadata: metadata));
  }

  /// Gets the annotation set in reverse insertion order.
  Iterable<CanvasAnnotation<T>> getAnnotations() {
    return _annotations.reversed;
  }

  /// Returns the topmost [CanvasAnnotation] under the given point. Returns null
  /// if there is no annotation under the point.
  CanvasAnnotation<T>? hitTest(Offset offset) {
    for (final annotation in getAnnotations()) {
      if (annotation.rect.contains(offset)) {
        return annotation;
      }
    }

    return null;
  }

  /// Returns all [CanvasAnnotation]s which are under the given offset.
  List<CanvasAnnotation<T>> hitTestAll(Offset offset) {
    return getAnnotations()
        .where((element) => element.rect.contains(offset))
        .toList();
  }
}
