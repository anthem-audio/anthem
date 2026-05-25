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

import 'piano_roll_state_machine_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PianoRollStateMachineTestFixture fixture;

  setUp(() {
    fixture = PianoRollStateMachineTestFixture.create();
  });

  tearDown(() {
    fixture.dispose();
  });

  group('live note preview interactions', () {
    test(
      'move preview sends note on/off events as the pitch changes',
      () async {
        final liveFixture = PianoRollStateMachineTestFixture.create(
          enableLiveEvents: true,
        );
        addTearDown(liveFixture.dispose);
        await Future<void>.delayed(Duration.zero);
        liveFixture.enableLiveEvents();

        final note = liveFixture.addNote(key: 60, offset: 100, length: 48);

        liveFixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: note.id,
        );
        liveFixture.pointerMove(key: 61.5, offset: 155.9, alt: true);
        liveFixture.pointerUp(key: 61.5, offset: 155.9, alt: true);

        expect(liveFixture.liveEvents, hasLength(4));

        final first = liveFixture.liveEvents[0];
        expect(
          first.liveEventProviderNodeId,
          equals(PianoRollStateMachineTestFixture.liveEventProviderNodeId),
        );
        expect(first.event, isA<LiveEventRequestNoteOnEvent>());
        expect((first.event as LiveEventRequestNoteOnEvent).pitch, equals(60));

        final second = liveFixture.liveEvents[1];
        expect(second.event, isA<LiveEventRequestNoteOffEvent>());
        expect(
          (second.event as LiveEventRequestNoteOffEvent).pitch,
          equals(60),
        );

        final third = liveFixture.liveEvents[2];
        expect(third.event, isA<LiveEventRequestNoteOnEvent>());
        expect((third.event as LiveEventRequestNoteOnEvent).pitch, equals(61));

        final fourth = liveFixture.liveEvents[3];
        expect(fourth.event, isA<LiveEventRequestNoteOffEvent>());
        expect(
          (fourth.event as LiveEventRequestNoteOffEvent).pitch,
          equals(61),
        );
      },
    );

    test(
      'create-note preview sends note off for the final preview pitch on cancel',
      () async {
        final liveFixture = PianoRollStateMachineTestFixture.create(
          enableLiveEvents: true,
        );
        addTearDown(liveFixture.dispose);
        await Future<void>.delayed(Duration.zero);
        liveFixture.enableLiveEvents();

        liveFixture.viewModel.cursorNoteLength = 48;

        liveFixture.pointerDown(key: 60.9, offset: 145.2, alt: true);
        liveFixture.pointerMove(key: 63.5, offset: 173.8, alt: true);
        liveFixture.pointerCancel(key: 63.5, offset: 173.8, alt: true);

        expect(liveFixture.liveEvents, hasLength(4));

        final events = liveFixture.liveEvents
            .map((entry) => entry.event)
            .toList(growable: false);
        expect(events[0], isA<LiveEventRequestNoteOnEvent>());
        expect((events[0] as LiveEventRequestNoteOnEvent).pitch, equals(60));
        expect(events[1], isA<LiveEventRequestNoteOffEvent>());
        expect((events[1] as LiveEventRequestNoteOffEvent).pitch, equals(60));
        expect(events[2], isA<LiveEventRequestNoteOnEvent>());
        expect((events[2] as LiveEventRequestNoteOnEvent).pitch, equals(63));
        expect(events[3], isA<LiveEventRequestNoteOffEvent>());
        expect((events[3] as LiveEventRequestNoteOffEvent).pitch, equals(63));
      },
    );

    test(
      'controller dispose sends note off for any active live preview note',
      () async {
        final liveFixture = PianoRollStateMachineTestFixture.create(
          enableLiveEvents: true,
        );
        addTearDown(liveFixture.dispose);
        await Future<void>.delayed(Duration.zero);
        liveFixture.enableLiveEvents();

        final note = liveFixture.addNote(key: 60, offset: 100, length: 48);

        liveFixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: note.id,
        );

        expect(liveFixture.liveEvents, hasLength(1));
        expect(
          liveFixture.liveEvents.single.event,
          isA<LiveEventRequestNoteOnEvent>(),
        );
        expect(
          (liveFixture.liveEvents.single.event as LiveEventRequestNoteOnEvent)
              .pitch,
          equals(60),
        );

        liveFixture.controller.dispose();

        expect(liveFixture.liveEvents, hasLength(2));
        expect(
          liveFixture.liveEvents[1].event,
          isA<LiveEventRequestNoteOffEvent>(),
        );
        expect(
          (liveFixture.liveEvents[1].event as LiveEventRequestNoteOffEvent)
              .pitch,
          equals(60),
        );
      },
    );
  });
}
