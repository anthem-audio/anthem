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
  final List<List<String>> subscriptionCalls = [];
  final List<double> updateIntervalCalls = [];

  @override
  void setSubscriptions(List<String> subscriptions) {
    subscriptionCalls.add(List<String>.unmodifiable(subscriptions));
  }

  @override
  void setUpdateInterval(double intervalMilliseconds) {
    updateIntervalCalls.add(intervalMilliseconds);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EngineAudioConfig testAudioConfig() {
    return EngineAudioConfig(
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
  }) {
    final visualizationApiMock = visualizationApi ?? MockVisualizationApi();

    final engineMock = MockEngine();
    when(engineMock.visualizationApi).thenReturn(visualizationApiMock);
    when(engineMock.audioConfig).thenReturn(testAudioConfig());
    when(engineMock.engineState).thenReturn(EngineState.running);
    when(
      engineMock.engineStateStream,
    ).thenAnswer((_) => const Stream<EngineState>.empty());
    when(engineMock.readyForMessages).thenAnswer((_) async {});

    final projectMock = MockProjectModel();
    when(projectMock.engine).thenReturn(engineMock);
    when(projectMock.engineState).thenReturn(EngineState.running);

    final visualizationProvider = VisualizationProvider(
      projectMock,
      wallClockNowForTest: wallClockNowForTest,
    );
    when(projectMock.visualizationProvider).thenReturn(visualizationProvider);

    return (
      project: projectMock,
      engine: engineMock,
      visualizationProvider: visualizationProvider,
    );
  }

  VisualizationItem testVisualizationItem({
    required String id,
    required List<Object> values,
    List<int>? sampleTimestamps,
    int startSample = 1,
  }) {
    return VisualizationItem(
      id: id,
      values: values,
      sampleTimestamps:
          sampleTimestamps ??
          List<int>.generate(values.length, (index) => startSample + index),
    );
  }

  Future<void> pumpMultiVisualizationBuilder(
    WidgetTester tester, {
    required ProjectModel project,
    required List<VisualizationSubscriptionConfig> configs,
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
    required VisualizationSubscriptionConfig config,
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

  test('Unbuffered latest and max subscriptions behave correctly', () {
    final setup = createProjectWithVisualizationProvider();

    final latest = setup.visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.latest('latest'),
    );
    final max = setup.visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.max('max'),
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

  test('String reads only expose native string subscriptions', () {
    var wallClock = Duration.zero;
    final setup = createProjectWithVisualizationProvider(
      wallClockNowForTest: () => wallClock,
    );

    final latestString = setup.visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.latest('string_latest'),
    );
    final latestDouble = setup.visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.latest('double_latest'),
    );

    setup.visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'string_latest',
            values: ['alpha'],
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

    expect(latestString.readValueString(), 'alpha');
    expect(
      latestString.readTimedValueString(),
      isA<TimedVisualizationValue<String>>()
          .having((value) => value.value, 'value', 'alpha')
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(11),
          ),
    );

    latestString.setOverride(
      valueString: 'override',
      duration: const Duration(seconds: 1),
    );
    expect(latestString.readValueString(), 'override');
    wallClock = const Duration(milliseconds: 5);
    expect(
      latestString.readTimedValueString(),
      isA<TimedVisualizationValue<String>>()
          .having((value) => value.value, 'value', 'override')
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(11) + const Duration(milliseconds: 5),
          ),
    );

    expect(() => latestDouble.readValueString(), throwsA(isA<StateError>()));
    expect(
      () => latestDouble.readTimedValueString(),
      throwsA(isA<StateError>()),
    );

    setup.visualizationProvider.dispose();
  });

  test('Timed reads expose engine sample timestamps for unbuffered values', () {
    final setup = createProjectWithVisualizationProvider();

    final latest = setup.visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.latest('latest'),
    );
    final max = setup.visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.max('max'),
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
      const VisualizationSubscriptionConfig.latest('initial_override'),
    );

    expect(initialOverride.readTimedValue(), isNull);

    initialOverride.setOverride(
      valueDouble: 1.0,
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
      const VisualizationSubscriptionConfig.latest('latest'),
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

    latest.setOverride(valueDouble: 9.0, duration: const Duration(seconds: 1));

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
        const VisualizationSubscriptionConfig.latest('subscriptionId'),
      );

      final malformedItem = VisualizationItem.uninitialized()
        ..id = 'subscriptionId'
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

    Future<List<String>> getNextSubscriptionChanges() async {
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
      VisualizationSubscriptionConfig.latest('subscriptionId1'),
    );
    final subscription2 = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latest('subscriptionId2'),
    );

    expect(
      await getNextSubscriptionChanges(),
      containsAll(['subscriptionId1', 'subscriptionId2']),
    );

    final subscription3 = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latest('subscriptionId3'),
    );

    expect(
      await getNextSubscriptionChanges(),
      containsAll(['subscriptionId1', 'subscriptionId2', 'subscriptionId3']),
    );

    final subscriptionDuplicate = setup.visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latest('subscriptionId3'),
    );

    await assertNoSubscriptionChanges();

    subscriptionDuplicate.dispose();

    await assertNoSubscriptionChanges();

    subscription3.dispose();

    expect(
      await getNextSubscriptionChanges(),
      containsAll(['subscriptionId1', 'subscriptionId2']),
    );

    subscription1.dispose();
    subscription2.dispose();

    expect(await getNextSubscriptionChanges(), isEmpty);
    setup.visualizationProvider.dispose();
  });

  testWidgets('Adaptive latest subscriptions render a delayed held timeline', (
    tester,
  ) async {
    var wallClock = Duration.zero;
    final setup = createProjectWithVisualizationProvider(
      wallClockNowForTest: () => wallClock,
    );

    final subscription = setup.visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.latest(
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
        const VisualizationSubscriptionConfig.max(
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
        config: const VisualizationSubscriptionConfig.latest('a'),
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
        config: const VisualizationSubscriptionConfig.latest('b'),
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
        configs: [const VisualizationSubscriptionConfig.latest('a')],
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
        configs: const [
          VisualizationSubscriptionConfig.latest('a'),
          VisualizationSubscriptionConfig.latest('b'),
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
        configs: const [
          VisualizationSubscriptionConfig.latest('a'),
          VisualizationSubscriptionConfig.latest('b'),
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
        configs: const [
          VisualizationSubscriptionConfig.latest('b'),
          VisualizationSubscriptionConfig.latest('a'),
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
