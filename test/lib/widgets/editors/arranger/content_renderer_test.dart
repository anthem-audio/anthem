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

import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem/widgets/editors/arranger/content_renderer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

ClipRenderInfo _makeClip({
  required Id id,
  required int offset,
  required int width,
  bool hasTimingOverride = false,
  Id trackId = 1,
}) {
  final pattern = PatternModel(
    idAllocator: ProjectEntityIdAllocator.test(() => id + 1000),
    name: '$id',
  );
  final clip = ClipModel(
    idAllocator: ProjectEntityIdAllocator.test(() => id),
    patternId: pattern.id,
    trackId: trackId,
    offset: offset,
    timeView: TimeViewModel(start: 0, end: width),
  );

  return ClipRenderInfo(
    pattern: pattern,
    clip: clip,
    hasTimingOverride: hasTimingOverride,
    clipOffset: offset,
    clipTimeViewStart: 0,
    clipTimeViewEnd: width,
    x: offset.toDouble(),
    y: 0,
    width: width.toDouble(),
    height: 48,
    selected: false,
    pressed: false,
    hovered: false,
  );
}

void main() {
  group('computeResizeHandleRects', () {
    Rect clipBodyRect({
      required double clipX,
      required double clipY,
      required double clipWidth,
      required double clipHeight,
    }) {
      final bodyWidth = (clipWidth - 1).clamp(1.0, double.infinity);
      return Rect.fromLTWH(clipX, clipY, bodyWidth, clipHeight - 1);
    }

    double insideOverlapWidth({required Rect handle, required Rect clipBody}) {
      final overlapLeft = handle.left > clipBody.left
          ? handle.left
          : clipBody.left;
      final overlapRight = handle.right < clipBody.right
          ? handle.right
          : clipBody.right;
      final width = overlapRight - overlapLeft;
      return width > 0 ? width : 0;
    }

    test(
      'very small clips keep entire body draggable and place handles outside',
      () {
        final clipX = 120.0;
        final clipY = 16.0;
        final clipWidth = 2.0;
        final clipHeight = 32.0;

        final handles = computeResizeHandleRects(
          clipX: clipX,
          clipY: clipY,
          clipWidth: clipWidth,
          clipHeight: clipHeight,
        );
        final clipBody = clipBodyRect(
          clipX: clipX,
          clipY: clipY,
          clipWidth: clipWidth,
          clipHeight: clipHeight,
        );

        final startInside = insideOverlapWidth(
          handle: handles.start,
          clipBody: clipBody,
        );
        final endInside = insideOverlapWidth(
          handle: handles.end,
          clipBody: clipBody,
        );

        expect(startInside, 0);
        expect(endInside, 0);
      },
    );

    test('typical clips keep at least 15px center drag area', () {
      final clipX = 64.0;
      final clipY = 8.0;
      final clipWidth = 120.0;
      final clipHeight = 48.0;

      final handles = computeResizeHandleRects(
        clipX: clipX,
        clipY: clipY,
        clipWidth: clipWidth,
        clipHeight: clipHeight,
      );
      final clipBody = clipBodyRect(
        clipX: clipX,
        clipY: clipY,
        clipWidth: clipWidth,
        clipHeight: clipHeight,
      );

      final startInside = insideOverlapWidth(
        handle: handles.start,
        clipBody: clipBody,
      );
      final endInside = insideOverlapWidth(
        handle: handles.end,
        clipBody: clipBody,
      );
      final dragArea = clipBody.width - startInside - endInside;

      expect(dragArea, greaterThanOrEqualTo(15));
    });

    test('small clips keep drag area equal to full clip width', () {
      final clipX = 44.0;
      final clipY = 8.0;
      final clipWidth = 10.0;
      final clipHeight = 48.0;

      final handles = computeResizeHandleRects(
        clipX: clipX,
        clipY: clipY,
        clipWidth: clipWidth,
        clipHeight: clipHeight,
      );
      final clipBody = clipBodyRect(
        clipX: clipX,
        clipY: clipY,
        clipWidth: clipWidth,
        clipHeight: clipHeight,
      );

      final startInside = insideOverlapWidth(
        handle: handles.start,
        clipBody: clipBody,
      );
      final endInside = insideOverlapWidth(
        handle: handles.end,
        clipBody: clipBody,
      );
      final dragArea = clipBody.width - startInside - endInside;

      expect(dragArea, closeTo(clipBody.width, 1e-9));
    });

    test('handle rects remain valid and non-empty', () {
      final handles = computeResizeHandleRects(
        clipX: 30,
        clipY: 4,
        clipWidth: 1.2,
        clipHeight: 22,
      );

      expect(handles.start.width, greaterThan(0));
      expect(handles.start.height, greaterThan(0));
      expect(handles.end.width, greaterThan(0));
      expect(handles.end.height, greaterThan(0));
    });
  });

  group('compareClipRenderInfoForLayering', () {
    test('orders timing overrides above non-overridden clips', () {
      final nonOverridden = _makeClip(id: 1, offset: 200, width: 24);
      final overridden = _makeClip(
        id: 2,
        offset: 0,
        width: 24,
        hasTimingOverride: true,
      );

      expect(
        compareClipRenderInfoForLayering(nonOverridden, overridden),
        lessThan(0),
      );
      expect(
        compareClipRenderInfoForLayering(overridden, nonOverridden),
        greaterThan(0),
      );
    });

    test('orders by offset when override state is equal', () {
      final earlier = _makeClip(id: 1, offset: 10, width: 24);
      final later = _makeClip(id: 2, offset: 40, width: 8);

      expect(compareClipRenderInfoForLayering(earlier, later), lessThan(0));
      expect(compareClipRenderInfoForLayering(later, earlier), greaterThan(0));
    });

    test('orders by width when offsets are equal', () {
      final narrower = _makeClip(id: 1, offset: 10, width: 8);
      final wider = _makeClip(id: 2, offset: 10, width: 24);

      expect(compareClipRenderInfoForLayering(narrower, wider), lessThan(0));
      expect(compareClipRenderInfoForLayering(wider, narrower), greaterThan(0));
    });

    test('falls back to clip ID when offset and width are equal', () {
      final clipA = _makeClip(id: 1, offset: 10, width: 24);
      final clipB = _makeClip(id: 2, offset: 10, width: 24);

      expect(compareClipRenderInfoForLayering(clipA, clipB), lessThan(0));
      expect(compareClipRenderInfoForLayering(clipB, clipA), greaterThan(0));
    });
  });

  group('buildClipLayersForPainting', () {
    test('places overridden overlapping clips in a later layer', () {
      final nonOverridden = _makeClip(id: 1, offset: 10, width: 30);
      final overridden = _makeClip(
        id: 2,
        offset: 20,
        width: 30,
        hasTimingOverride: true,
      );

      final layers = buildClipLayersForPainting([overridden, nonOverridden]);

      expect(layers, hasLength(2));
      expect(layers[0].map((clip) => clip.clipId), contains(1));
      expect(layers[1].map((clip) => clip.clipId), contains(2));
    });

    test('keeps touching clips in the same layer', () {
      final left = _makeClip(id: 1, offset: 10, width: 30);
      final right = _makeClip(id: 2, offset: 40, width: 30);

      final layers = buildClipLayersForPainting([right, left]);

      expect(layers, hasLength(1));
      expect(layers[0].map((clip) => clip.clipId).toList(), [1, 2]);
    });

    test('allows overlapping clips on different tracks in the same layer', () {
      final trackA = _makeClip(id: 1, trackId: 1, offset: 10, width: 30);
      final trackB = _makeClip(id: 2, trackId: 2, offset: 20, width: 30);

      final layers = buildClipLayersForPainting([trackB, trackA]);

      expect(layers, hasLength(1));
      expect(layers[0].map((clip) => clip.clipId), containsAll([1, 2]));
    });

    test('sorts clips before layer assignment', () {
      final early = _makeClip(id: 1, offset: 0, width: 20);
      final middle = _makeClip(id: 2, offset: 10, width: 15);
      final late = _makeClip(id: 3, offset: 20, width: 10);

      final layers = buildClipLayersForPainting([late, middle, early]);

      expect(layers, hasLength(3));
      expect(layers[0].single.clipId, 1);
      expect(layers[1].single.clipId, 2);
      expect(layers[2].single.clipId, 3);
    });

    test('returns clips to lower layers when overlap no longer exists', () {
      final base = _makeClip(id: 1, offset: 0, width: 10);
      final overlap = _makeClip(id: 2, offset: 5, width: 10);
      final nonOverlap = _makeClip(id: 3, offset: 16, width: 6);

      final layers = buildClipLayersForPainting([base, overlap, nonOverlap]);

      expect(layers, hasLength(2));
      expect(layers[0].map((clip) => clip.clipId).toList(), [1, 3]);
      expect(layers[1].map((clip) => clip.clipId).toList(), [2]);
    });
  });
}
