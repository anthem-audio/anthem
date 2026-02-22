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

import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem/widgets/editors/arranger/content_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

ClipRenderInfo _makeClip({
  required String id,
  required int offset,
  required int width,
  bool hasTimingOverride = false,
  String trackId = 'track-1',
}) {
  final pattern = PatternModel.create(name: id);
  final clip = ClipModel(
    id: id,
    patternId: 'pattern-$id',
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
  group('compareClipRenderInfoForLayering', () {
    test('orders timing overrides above non-overridden clips', () {
      final nonOverridden = _makeClip(id: 'clip-a', offset: 200, width: 24);
      final overridden = _makeClip(
        id: 'clip-b',
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
      final earlier = _makeClip(id: 'clip-a', offset: 10, width: 24);
      final later = _makeClip(id: 'clip-b', offset: 40, width: 8);

      expect(compareClipRenderInfoForLayering(earlier, later), lessThan(0));
      expect(compareClipRenderInfoForLayering(later, earlier), greaterThan(0));
    });

    test('orders by width when offsets are equal', () {
      final narrower = _makeClip(id: 'clip-a', offset: 10, width: 8);
      final wider = _makeClip(id: 'clip-b', offset: 10, width: 24);

      expect(compareClipRenderInfoForLayering(narrower, wider), lessThan(0));
      expect(compareClipRenderInfoForLayering(wider, narrower), greaterThan(0));
    });

    test('falls back to clip ID when offset and width are equal', () {
      final clipA = _makeClip(id: 'clip-a', offset: 10, width: 24);
      final clipB = _makeClip(id: 'clip-b', offset: 10, width: 24);

      expect(compareClipRenderInfoForLayering(clipA, clipB), lessThan(0));
      expect(compareClipRenderInfoForLayering(clipB, clipA), greaterThan(0));
    });
  });

  group('buildClipLayersForPainting', () {
    test('places overridden overlapping clips in a later layer', () {
      final nonOverridden = _makeClip(id: 'clip-a', offset: 10, width: 30);
      final overridden = _makeClip(
        id: 'clip-b',
        offset: 20,
        width: 30,
        hasTimingOverride: true,
      );

      final layers = buildClipLayersForPainting([overridden, nonOverridden]);

      expect(layers, hasLength(2));
      expect(layers[0].map((clip) => clip.clipId), contains('clip-a'));
      expect(layers[1].map((clip) => clip.clipId), contains('clip-b'));
    });

    test('keeps touching clips in the same layer', () {
      final left = _makeClip(id: 'clip-a', offset: 10, width: 30);
      final right = _makeClip(id: 'clip-b', offset: 40, width: 30);

      final layers = buildClipLayersForPainting([right, left]);

      expect(layers, hasLength(1));
      expect(layers[0].map((clip) => clip.clipId).toList(), [
        'clip-a',
        'clip-b',
      ]);
    });

    test('allows overlapping clips on different tracks in the same layer', () {
      final trackA = _makeClip(
        id: 'clip-a',
        trackId: 'track-1',
        offset: 10,
        width: 30,
      );
      final trackB = _makeClip(
        id: 'clip-b',
        trackId: 'track-2',
        offset: 20,
        width: 30,
      );

      final layers = buildClipLayersForPainting([trackB, trackA]);

      expect(layers, hasLength(1));
      expect(
        layers[0].map((clip) => clip.clipId),
        containsAll(['clip-a', 'clip-b']),
      );
    });

    test('sorts clips before layer assignment', () {
      final early = _makeClip(id: 'clip-a', offset: 0, width: 20);
      final middle = _makeClip(id: 'clip-b', offset: 10, width: 15);
      final late = _makeClip(id: 'clip-c', offset: 20, width: 10);

      final layers = buildClipLayersForPainting([late, middle, early]);

      expect(layers, hasLength(3));
      expect(layers[0].single.clipId, 'clip-a');
      expect(layers[1].single.clipId, 'clip-b');
      expect(layers[2].single.clipId, 'clip-c');
    });

    test('returns clips to lower layers when overlap no longer exists', () {
      final base = _makeClip(id: 'clip-a', offset: 0, width: 10);
      final overlap = _makeClip(id: 'clip-b', offset: 5, width: 10);
      final nonOverlap = _makeClip(id: 'clip-c', offset: 16, width: 6);

      final layers = buildClipLayersForPainting([base, overlap, nonOverlap]);

      expect(layers, hasLength(2));
      expect(layers[0].map((clip) => clip.clipId).toList(), [
        'clip-a',
        'clip-c',
      ]);
      expect(layers[1].map((clip) => clip.clipId).toList(), ['clip-b']);
    });
  });
}
