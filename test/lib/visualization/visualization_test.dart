/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'dart:async';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:anthem/engine_api/visualization_record.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

@GenerateNiceMocks([
  MockSpec<ProjectModel>(),
  MockSpec<Engine>(),
  MockSpec<VisualizationApi>(),
])
import 'visualization_test.mocks.dart';

class RecordingVisualizationApi extends Fake implements VisualizationApi {
  final List<List<VisualizationSubscriptionSpec>> subscriptionCalls = [];
  final List<double> updateIntervalCalls = [];

  @override
  void setSubscriptions(List<VisualizationSubscriptionSpec> subscriptions) {
    subscriptionCalls.add(
      List<VisualizationSubscriptionSpec>.unmodifiable(subscriptions),
    );
  }

  @override
  void setUpdateInterval(double intervalMilliseconds) {
    updateIntervalCalls.add(intervalMilliseconds);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AudioProcessingConfigDto testAudioConfig() {
    return AudioProcessingConfigDto(
      sampleRate: 48000,
      blockSize: 512,
      inputChannelCount: 2,
      outputChannelCount: 2,
    );
  }

  Duration engineTimeForSampleTimestamp(int sampleTimestamp) {
    return Duration(
      microseconds: (sampleTimestamp * Duration.microsecondsPerSecond / 48000)
          .round(),
    );
  }

  ({
    MockProjectModel project,
    MockEngine engine,
    VisualizationProvider visualizationProvider,
  })
  createProjectWithVisualizationProvider({
    Duration Function()? wallClockNowForTest,
    VisualizationApi? visualizationApi,
    Stream<EngineState>? engineStateStream,
  }) {
    final visualizationApiMock = visualizationApi ?? MockVisualizationApi();
    var currentEngineState = EngineState.running;
    final trackedEngineStateStream =
        (engineStateStream ?? const Stream<EngineState>.empty()).map((state) {
          currentEngineState = state;
          return state;
        });

    final engineMock = MockEngine();
    when(engineMock.visualizationApi).thenReturn(visualizationApiMock);
    when(engineMock.audioConfig).thenReturn(testAudioConfig());
    when(engineMock.engineState).thenAnswer((_) => currentEngineState);
    when(engineMock.engineStateStream)
        .thenAnswer((_) => trackedEngineStateStream);
    when(engineMock.readyForMessages).thenAnswer((_) async {});

    final projectMock = MockProjectModel();
    when(projectMock.engine).thenReturn(engineMock);
    when(projectMock.engineState).thenAnswer((_) => currentEngineState);

    final visualizationProvider = VisualizationProvider(
      projectMock,
      clock: wallClockNowForTest == null
          ? null
          : VisualizationClock(wallClockNowForTest),
    );
    when(projectMock.visualizationProvider).thenReturn(visualizationProvider);

    return (
      project: projectMock,
      engine: engineMock,
      visualizationProvider: visualizationProvider,
    );
  }

  VisualizationValueType inferVisualizationValueType<T extends num>() {
    // int and double runtime checks overlap in JavaScript. Use the fixture's
    // static element type to keep its declared wire type unambiguous.
    if (T == double) {
      return VisualizationValueType.doubleValue;
    }
    if (T == int) {
      return VisualizationValueType.intValue;
    }
    throw ArgumentError('Could not infer a visualization value type for $T.');
  }

  VisualizationItem testVisualizationItem<T extends num>({
    required String id,
    required List<T> values,
    VisualizationValueType? valueType,
    List<int>? sampleTimestamps,
    int startSample = 1,
  }) {
    return VisualizationItem(
      id: id,
      valueType: valueType ?? inferVisualizationValueType<T>(),
      values: T == int ? values as List<int> : values as List<double>,
      sampleTimestamps:
          sampleTimestamps ??
          List<int>.generate(values.length, (index) => startSample + index),
    );
  }

  Future<void> pumpMultiVisualizationBuilder(
    WidgetTester tester, {
    required ProjectModel project,
    required List<VisualizationSubscriptionConfig<int>> configs,
  }) async {
    await tester.pumpWidget(
      Provider<ProjectModel>.value(
        value: project,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MultiVisualizationBuilder.int(
            configs: configs,
            builder: (context, values, engineTimes) {
              return Text(values.join(','), textDirection: TextDirection.ltr);
            },
          ),
        ),
      ),
    );
  }

  Future<void> pumpVisualizationBuilder(
    WidgetTester tester, {
    required ProjectModel project,
    required VisualizationSubscriptionConfig<int> config,
  }) async {
    await tester.pumpWidget(
      Provider<ProjectModel>.value(
        value: project,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: VisualizationBuilder.int(
            config: config,
            builder: (context, value, engineTime) {
              return Text(
                value?.toString() ?? 'null',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets(
    'VisualizationSubscriptionController caches values and resets on config changes',
    (tester) async {
      final setup = createProjectWithVisualizationProvider();
      final controller = VisualizationSubscriptionController<int>(
        visualizationProvider: setup.visualizationProvider,
        config: VisualizationSubscriptionConfig.latestInt('a'),
      );
      var notificationCount = 0;

      controller.addListener(() {
        notificationCount++;
      });

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'a',
              values: [3],
              sampleTimestamps: [240],
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(controller.value, 3);
      expect(controller.engineTime, engineTimeForSampleTimestamp(240));
      expect(notificationCount, 1);

      controller.update(config: VisualizationSubscriptionConfig.latestInt('b'));

      expect(controller.value, isNull);
      expect(controller.engineTime, isNull);
      expect(notificationCount, 2);

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'a',
              values: [9],
              sampleTimestamps: [480],
            ),
            testVisualizationItem(
              id: 'b',
              values: [4],
              sampleTimestamps: [720],
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(controller.value, 4);
      expect(controller.engineTime, engineTimeForSampleTimestamp(720));
      expect(notificationCount, 3);

      controller.dispose();
      setup.visualizationProvider.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'MultiVisualizationSubscriptionController reorders cached values positionally',
    (tester) async {
      final setup = createProjectWithVisualizationProvider();
      final controller = MultiVisualizationSubscriptionController<int>(
        visualizationProvider: setup.visualizationProvider,
        configs: [
          VisualizationSubscriptionConfig.latestInt('a'),
          VisualizationSubscriptionConfig.latestInt('b'),
        ],
      );
      var notificationCount = 0;

      controller.addListener(() {
        notificationCount++;
      });

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'a',
              values: [1],
              sampleTimestamps: [120],
            ),
            testVisualizationItem(
              id: 'b',
              values: [2],
              sampleTimestamps: [240],
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(controller.values, [1, 2]);
      expect(controller.engineTimes, [
        engineTimeForSampleTimestamp(120),
        engineTimeForSampleTimestamp(240),
      ]);
      expect(notificationCount, 2);

      controller.update(
        configs: [
          VisualizationSubscriptionConfig.latestInt('b'),
          VisualizationSubscriptionConfig.latestInt('a'),
        ],
      );

      expect(controller.values, [2, 1]);
      expect(controller.engineTimes, [
        engineTimeForSampleTimestamp(240),
        engineTimeForSampleTimestamp(120),
      ]);
      expect(notificationCount, 3);

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'a',
              values: [4],
              sampleTimestamps: [360],
            ),
            testVisualizationItem(
              id: 'b',
              values: [3],
              sampleTimestamps: [300],
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(controller.values, [3, 4]);
      expect(controller.engineTimes, [
        engineTimeForSampleTimestamp(300),
        engineTimeForSampleTimestamp(360),
      ]);

      controller.dispose();
      setup.visualizationProvider.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'Active visualization controllers reset cached values when the engine stops',
    (tester) async {
      final engineStates = StreamController<EngineState>.broadcast();
      final setup = createProjectWithVisualizationProvider(
        engineStateStream: engineStates.stream,
      );
      final singleController = VisualizationSubscriptionController<int>(
        visualizationProvider: setup.visualizationProvider,
        config: VisualizationSubscriptionConfig.latestInt('single'),
        minimumUpdateInterval: const Duration(seconds: 1),
      );
      final multiController = MultiVisualizationSubscriptionController<int>(
        visualizationProvider: setup.visualizationProvider,
        configs: [
          VisualizationSubscriptionConfig.latestInt('left'),
          VisualizationSubscriptionConfig.latestInt('right'),
        ],
        minimumUpdateInterval: const Duration(seconds: 1),
      );

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'single',
              values: [9],
              sampleTimestamps: [480],
            ),
            testVisualizationItem(
              id: 'left',
              values: [3],
              sampleTimestamps: [960],
            ),
            testVisualizationItem(
              id: 'right',
              values: [4],
              sampleTimestamps: [1440],
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(singleController.value, 9);
      expect(singleController.engineTime, engineTimeForSampleTimestamp(480));
      expect(multiController.values, [3, 4]);
      expect(multiController.engineTimes, [
        engineTimeForSampleTimestamp(960),
        engineTimeForSampleTimestamp(1440),
      ]);

      engineStates.add(EngineState.stopped);
      await tester.pump();

      expect(singleController.value, 0);
      expect(singleController.engineTime, isNull);
      expect(multiController.values, [0, 0]);
      expect(multiController.engineTimes, [null, null]);

      singleController.dispose();
      multiController.dispose();
      setup.visualizationProvider.dispose();
      await engineStates.close();
      await tester.pump();
    },
  );

  test('Unbuffered latest and max subscriptions behave correctly', () {
    final setup = createProjectWithVisualizationProvider();

    final latest = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('latest'),
    );
    final max = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.max('max'),
    );

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(id: 'latest', values: [0.5]),
          testVisualizationItem(id: 'max', values: [0.5]),
        ],
      ),
    );

    expect(latest.readValue(), 0.5);
    expect(max.readValue(), 0.5);

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(id: 'latest', values: [0.6, 0.7, 0.8]),
          testVisualizationItem(id: 'max', values: [0.6, 1.2, 0.8]),
        ],
      ),
    );

    expect(latest.readValue(), 0.8);
    expect(max.readValue(), 1.2);

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(id: 'max', values: [0.7, 0.9]),
        ],
      ),
    );

    expect(max.readValue(), 0.9);
    expect(max.readValue(), 0.9);

    setup.visualizationProvider.dispose();
  });

  test('Integer subscriptions expose typed reads and overrides', () {
    var wallClock = Duration.zero;
    final setup = createProjectWithVisualizationProvider(
      wallClockNowForTest: () => wallClock,
    );

    final latestInt = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestInt('int_latest'),
    );
    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'int_latest',
            values: [7],
            sampleTimestamps: [11],
          ),
          testVisualizationItem(
            id: 'double_latest',
            values: [7.5],
            sampleTimestamps: [41],
          ),
        ],
      ),
    );

    expect(latestInt.readValue(), 7);
    expect(
      latestInt.readTimedValue(),
      isA<TimedVisualizationValue<int>>()
          .having((value) => value.value, 'value', 7)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(11),
          ),
    );

    latestInt.setOverride(value: 9, duration: const Duration(seconds: 1));
    expect(latestInt.readValue(), 9);
    wallClock = const Duration(milliseconds: 5);
    expect(
      latestInt.readTimedValue(),
      isA<TimedVisualizationValue<int>>()
          .having((value) => value.value, 'value', 9)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(11) + const Duration(milliseconds: 5),
          ),
    );

    setup.visualizationProvider.dispose();
  });

  test('Timed reads expose engine sample timestamps for unbuffered values', () {
    final setup = createProjectWithVisualizationProvider();

    final latest = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('latest'),
    );
    final max = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.max('max'),
    );

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'latest',
            values: [1.0, 2.0],
            sampleTimestamps: [100, 120],
          ),
          testVisualizationItem(
            id: 'max',
            values: [0.5, 1.5, 1.0],
            sampleTimestamps: [130, 150, 160],
          ),
        ],
      ),
    );

    expect(
      latest.readTimedValue(),
      isA<TimedVisualizationValue<double>>()
          .having((value) => value.value, 'value', 2.0)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(120),
          ),
    );
    expect(
      max.readTimedValue(),
      isA<TimedVisualizationValue<double>>()
          .having((value) => value.value, 'value', 1.5)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(150),
          ),
    );

    setup.visualizationProvider.dispose();
  });

  test('Timed overrides use an extrapolated engine-time anchor', () {
    var wallClock = Duration.zero;
    final setup = createProjectWithVisualizationProvider(
      wallClockNowForTest: () => wallClock,
    );

    final initialOverride = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('initial_override'),
    );

    expect(initialOverride.readTimedValue(), isNull);

    initialOverride.setOverride(
      value: 1.0,
      duration: const Duration(seconds: 1),
    );
    expect(
      initialOverride.readTimedValue(),
      isA<TimedVisualizationValue<double>>()
          .having((value) => value.value, 'value', 1.0)
          .having((value) => value.engineTime, 'engineTime', Duration.zero),
    );

    wallClock = const Duration(milliseconds: 10);
    expect(
      initialOverride.readTimedValue(),
      isA<TimedVisualizationValue<double>>()
          .having((value) => value.value, 'value', 1.0)
          .having(
            (value) => value.engineTime,
            'engineTime',
            const Duration(milliseconds: 10),
          ),
    );

    final latest = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('latest'),
    );

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'latest',
            values: [4.0],
            sampleTimestamps: [500],
          ),
        ],
      ),
    );

    wallClock = const Duration(milliseconds: 20);

    expect(
      latest.readTimedValue(),
      isA<TimedVisualizationValue<double>>()
          .having((value) => value.value, 'value', 4.0)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(500),
          ),
    );

    latest.setOverride(value: 9.0, duration: const Duration(seconds: 1));

    expect(latest.readValue(), 9.0);
    wallClock = const Duration(milliseconds: 35);
    expect(
      latest.readTimedValue(),
      isA<TimedVisualizationValue<double>>()
          .having((value) => value.value, 'value', 9.0)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(500) +
                const Duration(milliseconds: 15),
          ),
    );

    setup.visualizationProvider.dispose();
  });

  test(
    'Visualization updates reject mismatched value and timestamp counts',
    () {
      final setup = createProjectWithVisualizationProvider();
      setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.latestDouble('subscriptionId'),
      );

      final malformedItem = VisualizationItem.uninitialized()
        ..id = 'subscriptionId'
        ..valueType = VisualizationValueType.doubleValue
        ..values = [1.0, 2.0]
        ..sampleTimestamps = [10];

      expect(
        () => setup.visualizationProvider.processVisualizationUpdate(
          VisualizationUpdateEvent(id: 0, items: [malformedItem]),
        ),
        throwsA(isA<StateError>()),
      );

      setup.visualizationProvider.dispose();
    },
  );

  test('Visualization updates are ignored without an active audio config', () {
    final setup = createProjectWithVisualizationProvider();
    when(setup.engine.audioConfig).thenReturn(null);

    final subscription = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('subscriptionId'),
    );

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'subscriptionId',
            valueType: VisualizationValueType.doubleValue,
            values: [1.0],
            sampleTimestamps: [10],
          ),
        ],
      ),
    );

    expect(subscription.readValue(), equals(0.0));

    setup.visualizationProvider.dispose();
  });

  test('Visualization updates reject mismatched declared value types', () {
    final setup = createProjectWithVisualizationProvider();
    setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestInt('subscriptionId'),
    );

    expect(
      () => setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'subscriptionId',
              valueType: VisualizationValueType.doubleValue,
              values: [1.0],
            ),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    setup.visualizationProvider.dispose();
  });

  test(
    'Visualization subscriptions reject conflicting declared value types',
    () {
      final setup = createProjectWithVisualizationProvider();
      setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.latestDouble('subscriptionId'),
      );

      expect(
        () => setup.visualizationProvider.subscribe(
          VisualizationSubscriptionConfig.latestInt('subscriptionId'),
        ),
        throwsA(isA<StateError>()),
      );

      setup.visualizationProvider.dispose();
    },
  );

  test('VisualizationProvider seeds late subscribers from cached values', () {
    final setup = createProjectWithVisualizationProvider();

    final early = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestInt('playhead_sequence_id'),
    );

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'playhead_sequence_id',
            values: [10, 11],
            sampleTimestamps: [240, 480],
          ),
        ],
      ),
    );

    expect(
      early.readTimedValue(),
      isA<TimedVisualizationValue<int>>()
          .having((value) => value.value, 'value', 11)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(480),
          ),
    );

    final late = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestInt('playhead_sequence_id'),
    );

    expect(
      late.readTimedValue(),
      isA<TimedVisualizationValue<int>>()
          .having((value) => value.value, 'value', 11)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(480),
          ),
    );

    early.dispose();
    late.dispose();
    setup.visualizationProvider.dispose();
  });

  test(
    'Refreshed sequence IDs seed late subscribers after audio reconfiguration',
    () {
      final setup = createProjectWithVisualizationProvider();
      addTearDown(setup.visualizationProvider.dispose);
      final early = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.latestInt('playhead_sequence_id'),
      );
      var sequence = 0;

      void update(int generation, int timestamp, List<int> ids) {
        setup.visualizationProvider.processVisualizationRecord(
          VisualizationRecord(
            sequence: sequence++,
            generation: generation,
            sampleRate: 48000,
            newestSampleTimestamp: timestamp,
            update: VisualizationUpdateEvent(
              id: -1,
              items: [
                if (ids.isNotEmpty)
                  testVisualizationItem(
                    id: 'playhead_sequence_id',
                    values: ids,
                    sampleTimestamps: [timestamp],
                  ),
              ],
            ),
          ),
        );
      }

      update(1, 48000, [42]);
      expect(early.readValue(), 42);
      update(2, 0, []);
      expect(early.readValue(), 42);

      final duringReset = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.latestInt('playhead_sequence_id'),
      );
      expect(duringReset.readTimedValue(), isNull);

      // The next periodic snapshot restores the unchanged ID on the new clock.
      update(2, 480, [42]);
      final afterRefresh = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.latestInt('playhead_sequence_id'),
      );
      for (final subscription in [early, duringReset, afterRefresh]) {
        expect(
          subscription.readTimedValue(),
          isA<TimedVisualizationValue<int>>()
              .having((value) => value.value, 'value', 42)
              .having(
                (value) => value.engineTime,
                'engineTime',
                engineTimeForSampleTimestamp(480),
              ),
        );
      }
    },
  );

  test(
    'VisualizationProvider clears cached values when the engine stops',
    () async {
      final engineStates = StreamController<EngineState>.broadcast();
      final setup = createProjectWithVisualizationProvider(
        engineStateStream: engineStates.stream,
      );

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'playhead_sequence_id',
              values: [12],
              sampleTimestamps: [960],
            ),
          ],
        ),
      );

      final beforeStop = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.latestInt('playhead_sequence_id'),
      );
      expect(beforeStop.readValue(), 12);

      engineStates.add(EngineState.stopped);
      await Future<void>.delayed(Duration.zero);

      expect(beforeStop.readTimedValue(), isNull);
      expect(beforeStop.readValue(), 0);

      final afterStop = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.latestInt('playhead_sequence_id'),
      );
      expect(afterStop.readTimedValue(), isNull);
      expect(afterStop.readValue(), 0);

      beforeStop.dispose();
      afterStop.dispose();
      setup.visualizationProvider.dispose();
      await engineStates.close();
    },
  );

  test(
    'Cached visualization values reject conflicting declared value types',
    () {
      final setup = createProjectWithVisualizationProvider();

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(id: 'cached', values: [1]),
          ],
        ),
      );

      expect(
        () => setup.visualizationProvider.subscribe(
          VisualizationSubscriptionConfig.latestDouble('cached'),
        ),
        throwsA(isA<StateError>()),
      );

      setup.visualizationProvider.dispose();
    },
  );

  test('Visualization updates are correct', () async {
    final recordingVisualizationApi = RecordingVisualizationApi();
    final setup = createProjectWithVisualizationProvider(
      visualizationApi: recordingVisualizationApi,
    );

    Future<void> assertNoSubscriptionChanges() async {
      final previousCallCount =
          recordingVisualizationApi.subscriptionCalls.length;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        recordingVisualizationApi.subscriptionCalls,
        hasLength(previousCallCount),
      );
    }

    Future<List<VisualizationSubscriptionSpec>>
    getNextSubscriptionChanges() async {
      final previousCallCount =
          recordingVisualizationApi.subscriptionCalls.length;

      await Future<void>.delayed(const Duration(milliseconds: 50));

      if (recordingVisualizationApi.subscriptionCalls.length ==
          previousCallCount) {
        fail('Expected subscription changes, but got none.');
      }

      return recordingVisualizationApi.subscriptionCalls.last;
    }

    final subscription1 = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('subscriptionId1'),
    );
    final subscription2 = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestInt('subscriptionId2'),
    );

    final initialSubscriptions = await getNextSubscriptionChanges();
    expect(
      initialSubscriptions.map((spec) => spec.id),
      containsAll(['subscriptionId1', 'subscriptionId2']),
    );
    expect(
      initialSubscriptions
          .firstWhere((spec) => spec.id == 'subscriptionId2')
          .valueType,
      VisualizationValueType.intValue,
    );

    final subscription3 = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('subscriptionId3'),
    );

    expect(
      (await getNextSubscriptionChanges()).map((spec) => spec.id),
      containsAll(['subscriptionId1', 'subscriptionId2', 'subscriptionId3']),
    );

    final subscriptionDuplicate = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('subscriptionId3'),
    );

    await assertNoSubscriptionChanges();

    subscriptionDuplicate.dispose();

    await assertNoSubscriptionChanges();

    subscription3.dispose();

    expect(
      (await getNextSubscriptionChanges()).map((spec) => spec.id),
      containsAll(['subscriptionId1', 'subscriptionId2']),
    );

    subscription1.dispose();
    subscription2.dispose();

    expect(await getNextSubscriptionChanges(), isEmpty);
    setup.visualizationProvider.dispose();
  });

  testWidgets(
    'transport recovery discards old history and preserves recent meter peaks',
    (tester) async {
      var wallClock = Duration.zero;
      final setup = createProjectWithVisualizationProvider(
        wallClockNowForTest: () => wallClock,
      );
      final playhead = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.latestDouble(
          'playhead',
          bufferMode: VisualizationBufferMode.adaptive,
        ),
      );
      final meter = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.max(
          'meter',
          bufferMode: VisualizationBufferMode.adaptive,
        ),
      );
      void update(
        int sequence,
        List<int> timestamps,
        List<double> positions,
        List<double> peaks, {
        bool discontinuity = false,
      }) {
        setup.visualizationProvider.processVisualizationRecord(
          VisualizationRecord(
            sequence: sequence,
            generation: 1,
            sampleRate: 48000,
            newestSampleTimestamp: timestamps.last,
            discontinuity: discontinuity,
            update: VisualizationUpdateEvent(
              id: -1,
              items: [
                testVisualizationItem(
                  id: 'playhead',
                  values: positions,
                  sampleTimestamps: timestamps,
                ),
                testVisualizationItem(
                  id: 'meter',
                  values: peaks,
                  sampleTimestamps: timestamps,
                ),
              ],
            ),
          ),
        );
      }

      update(1, [0, 768], [0, 1], [99, 1]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      wallClock = const Duration(seconds: 2);
      update(2, [96000, 96768, 97536], [100, 101, 102], [
        0.2,
        0.8,
        0.3,
      ], discontinuity: true);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        playhead.readTimedValue()!.engineTime,
        greaterThanOrEqualTo(const Duration(seconds: 2)),
      );
      expect(playhead.readValue(), 102);
      expect(meter.readValue(), closeTo(0.8, 0.00001));
      setup.visualizationProvider.dispose();
      await tester.pump();
    },
  );

  test('transport discontinuities preserve active overrides and reject old sessions', () {
    final setup = createProjectWithVisualizationProvider();
    final subscription = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('value'),
    );
    subscription.setOverride(value: 42, duration: const Duration(seconds: 10));
    void update(int generation, double value) {
      setup.visualizationProvider.processVisualizationRecord(
        VisualizationRecord(
          sequence: 1,
          generation: generation,
          sampleRate: 48000,
          newestSampleTimestamp: 10,
          discontinuity: true,
          update: VisualizationUpdateEvent(
            id: -1,
            items: [
              testVisualizationItem(
                id: 'value',
                values: [value],
                sampleTimestamps: [10],
              ),
            ],
          ),
        ),
      );
    }

    update(2, 7);
    update(1, 9);
    expect(subscription.readValue(), 42);
    final lateSubscription = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble('value'),
    );
    expect(lateSubscription.readValue(), 7);
    setup.visualizationProvider.dispose();
  });

  for (final scenario in [
    (name: 'consumed peaks', peakTime: 0, expected: 1.0),
    (name: 'stale unseen peaks', peakTime: 512, expected: 1.0),
    (name: 'recent unseen peaks', peakTime: 1904, expected: 10.0),
  ]) {
    testWidgets('Adaptive meter catch-up handles ${scenario.name}', (
      tester,
    ) async {
      var wallClock = Duration.zero;
      final setup = createProjectWithVisualizationProvider(
        wallClockNowForTest: () => wallClock,
      );
      final meter = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.max(
          'meter',
          bufferMode: VisualizationBufferMode.adaptive,
        ),
      );
      var sequence = 0;
      void update(int milliseconds, double value) {
        wallClock = Duration(milliseconds: milliseconds);
        final timestamp = milliseconds * 48;
        setup.visualizationProvider.processVisualizationRecord(
          VisualizationRecord(
            sequence: sequence++,
            generation: 1,
            sampleRate: 48000,
            newestSampleTimestamp: timestamp,
            update: VisualizationUpdateEvent(
              id: -1,
              items: [
                testVisualizationItem(
                  id: 'meter',
                  values: [value],
                  sampleTimestamps: [timestamp],
                ),
              ],
            ),
          ),
        );
      }

      try {
        update(0, 10);
        update(16, 1);
        await tester.pump();
        expect(meter.readValue(), 10);
        update(32, 1);
        await tester.pump(const Duration(milliseconds: 16));
        expect(meter.readValue(), 1);

        // Polling continues without frames, so no delivery discontinuity clears
        // the buffer. The next frame must bound its own peak recovery window.
        for (var milliseconds = 48; milliseconds <= 2000; milliseconds += 16) {
          update(milliseconds, milliseconds == scenario.peakTime ? 10 : 1);
        }
        await tester.pump(const Duration(milliseconds: 1968));
        expect(meter.readValue(), scenario.expected);
      } finally {
        setup.visualizationProvider.dispose();
        await tester.pump();
      }
    });
  }

  testWidgets('Adaptive latest subscriptions render a delayed held timeline', (
    tester,
  ) async {
    var wallClock = Duration.zero;
    final setup = createProjectWithVisualizationProvider(
      wallClockNowForTest: () => wallClock,
    );

    final subscription = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latestDouble(
        'playhead_position',
        bufferMode: VisualizationBufferMode.adaptive,
      ),
    );

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'playhead_position',
            values: [0.0],
            sampleTimestamps: [0],
          ),
        ],
      ),
    );

    wallClock = const Duration(milliseconds: 16);
    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'playhead_position',
            values: [1.0],
            sampleTimestamps: [768],
          ),
        ],
      ),
    );

    wallClock = const Duration(milliseconds: 56);
    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'playhead_position',
            values: [2.0],
            sampleTimestamps: [1536],
          ),
        ],
      ),
    );

    wallClock = const Duration(milliseconds: 72);
    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'playhead_position',
            values: [3.0],
            sampleTimestamps: [2304],
          ),
        ],
      ),
    );

    await tester.pump(const Duration(milliseconds: 16));

    final timedValue = subscription.readTimedValue();
    expect(timedValue, isNotNull);
    expect(
      timedValue!.engineTime,
      greaterThan(engineTimeForSampleTimestamp(1536)),
    );
    expect(timedValue.engineTime, lessThan(engineTimeForSampleTimestamp(2304)));
    expect(timedValue.value, 2.0);

    setup.visualizationProvider.dispose();
    await tester.pump();
  });

  testWidgets(
    'Adaptive max subscriptions render delayed maxima instead of newest packets',
    (tester) async {
      var wallClock = Duration.zero;
      final setup = createProjectWithVisualizationProvider(
        wallClockNowForTest: () => wallClock,
      );

      final subscription = setup.visualizationProvider.subscribe(
        VisualizationSubscriptionConfig.max(
          'meter',
          bufferMode: VisualizationBufferMode.adaptive,
        ),
      );

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'meter',
              values: [1.0],
              sampleTimestamps: [0],
            ),
          ],
        ),
      );

      wallClock = const Duration(milliseconds: 16);
      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'meter',
              values: [3.0],
              sampleTimestamps: [768],
            ),
          ],
        ),
      );

      wallClock = const Duration(milliseconds: 56);
      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'meter',
              values: [2.0],
              sampleTimestamps: [1536],
            ),
          ],
        ),
      );

      wallClock = const Duration(milliseconds: 72);
      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(
              id: 'meter',
              values: [4.0],
              sampleTimestamps: [2304],
            ),
          ],
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));

      final timedValue = subscription.readTimedValue();
      expect(timedValue, isNotNull);
      expect(
        timedValue!.engineTime,
        greaterThan(engineTimeForSampleTimestamp(1536)),
      );
      expect(
        timedValue.engineTime,
        lessThan(engineTimeForSampleTimestamp(2304)),
      );
      expect(timedValue.value, 3.0);
      expect(subscription.readValue(), 3.0);

      setup.visualizationProvider.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'VisualizationBuilder keeps receiving updates after a config change',
    (tester) async {
      final setup = createProjectWithVisualizationProvider();

      await pumpVisualizationBuilder(
        tester,
        project: setup.project,
        config: VisualizationSubscriptionConfig.latestInt('a'),
      );

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(id: 'a', values: [1]),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('1'), findsOneWidget);

      await pumpVisualizationBuilder(
        tester,
        project: setup.project,
        config: VisualizationSubscriptionConfig.latestInt('b'),
      );

      expect(find.text('null'), findsOneWidget);

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(id: 'a', values: [9]),
            testVisualizationItem(id: 'b', values: [2]),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('2'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      setup.visualizationProvider.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'MultiVisualizationBuilder recreates subscriptions when the config count changes',
    (tester) async {
      final setup = createProjectWithVisualizationProvider();

      await pumpMultiVisualizationBuilder(
        tester,
        project: setup.project,
        configs: [VisualizationSubscriptionConfig.latestInt('a')],
      );

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(id: 'a', values: [1]),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('1'), findsOneWidget);

      await pumpMultiVisualizationBuilder(
        tester,
        project: setup.project,
        configs: [
          VisualizationSubscriptionConfig.latestInt('a'),
          VisualizationSubscriptionConfig.latestInt('b'),
        ],
      );

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(id: 'a', values: [2]),
            testVisualizationItem(id: 'b', values: [3]),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('2,3'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      setup.visualizationProvider.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'MultiVisualizationBuilder reorders subscriptions positionally when configs are reordered',
    (tester) async {
      final setup = createProjectWithVisualizationProvider();

      await pumpMultiVisualizationBuilder(
        tester,
        project: setup.project,
        configs: [
          VisualizationSubscriptionConfig.latestInt('a'),
          VisualizationSubscriptionConfig.latestInt('b'),
        ],
      );

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(id: 'a', values: [1]),
            testVisualizationItem(id: 'b', values: [2]),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('1,2'), findsOneWidget);

      await pumpMultiVisualizationBuilder(
        tester,
        project: setup.project,
        configs: [
          VisualizationSubscriptionConfig.latestInt('b'),
          VisualizationSubscriptionConfig.latestInt('a'),
        ],
      );

      setup.visualizationProvider.processVisualizationUpdate(
        VisualizationUpdateEvent(
          id: 0,
          items: [
            testVisualizationItem(id: 'a', values: [4]),
            testVisualizationItem(id: 'b', values: [3]),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('3,4'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      setup.visualizationProvider.dispose();
      await tester.pump();
    },
  );
}
