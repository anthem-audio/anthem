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

import 'package:anthem/widgets/editors/arranger/widgets/track_header_resize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sticks to the default height inside the dead zone', () {
    final result = calculateTrackHeaderResize(
      initialPixelHeight: 80,
      initialModifier: 2,
      pointerY: -35,
      isSendTrack: false,
      state: const TrackHeaderResizeDragState(
        pointerOriginY: 0,
        ignoresDeadZone: false,
      ),
    );

    expect(result.pixelHeight, 40);
    expect(result.modifier, 1);
  });

  test('subtracts the dead-zone width after crossing it', () {
    final result = calculateTrackHeaderResize(
      initialPixelHeight: 80,
      initialModifier: 2,
      pointerY: -20,
      isSendTrack: false,
      state: const TrackHeaderResizeDragState(
        pointerOriginY: 0,
        ignoresDeadZone: false,
      ),
    );

    expect(result.pixelHeight, 52);
    expect(result.modifier, closeTo(1.3, 0.000001));
  });

  test('leaves an initially ignored dead zone without jumping', () {
    final initialState = TrackHeaderResizeDragState.initial(
      pointerY: 0,
      initialModifier: 1,
    );

    final insideResult = calculateTrackHeaderResize(
      initialPixelHeight: 60,
      initialModifier: 1,
      pointerY: 8,
      isSendTrack: false,
      state: initialState,
    );
    final outsideResult = calculateTrackHeaderResize(
      initialPixelHeight: 60,
      initialModifier: 1,
      pointerY: 9,
      isSendTrack: false,
      state: insideResult.state,
    );

    expect(insideResult.pixelHeight, 68);
    expect(outsideResult.pixelHeight, 69);
    expect(outsideResult.state.ignoresDeadZone, isFalse);
    expect(outsideResult.state.pointerOriginY, -8);
  });

  test('reverses pointer movement for send tracks', () {
    final result = calculateTrackHeaderResize(
      initialPixelHeight: 60,
      initialModifier: 1,
      pointerY: -12,
      isSendTrack: true,
      state: TrackHeaderResizeDragState.initial(
        pointerY: 0,
        initialModifier: 1,
      ),
    );

    expect(result.pixelHeight, 72);
    expect(result.modifier, closeTo(1.2, 0.000001));
  });
}
