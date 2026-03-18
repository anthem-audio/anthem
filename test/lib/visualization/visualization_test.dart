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
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

@GenerateNiceMocks([
  MockSpec<ProjectModel>(),
  MockSpec<Engine>(),
  MockSpec<VisualizationApi>(),
])
import 'visualization_test.mocks.dart';

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
  createProjectWithVisualizationProvider() {
    final visualizationApiMock = MockVisualizationApi();

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

    final visualizationProvider = VisualizationProvider(projectMock);
    when(projectMock.visualizationProvider).thenReturn(visualizationProvider);

    return (
      project: projectMock,
      engine: engineMock,
      visualizationProvider: visualizationProvider,
    );
  }

  VisualizationItem testVisualizationItem({
    required String id,
    required Object values,
    List<int>? sampleTimestamps,
    int startSample = 1,
  }) {
    final valueList = values as List;

    return VisualizationItem(
      id: id,
      values: values,
      sampleTimestamps:
          sampleTimestamps ??
          List<int>.generate(valueList.length, (index) => startSample + index),
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

  test('Subscription object behavior', () {
    for (final value in VisualizationSubscriptionType.values) {
      final visualizationApiMock = MockVisualizationApi();

      final engineMock = MockEngine();
      when(engineMock.visualizationApi).thenReturn(visualizationApiMock);
      when(engineMock.audioConfig).thenReturn(testAudioConfig());

      final projectMock = MockProjectModel();
      when(projectMock.engine).thenReturn(engineMock);

      final visualizationProvider = VisualizationProvider(projectMock);

      switch (value) {
        case VisualizationSubscriptionType.latest:
          final subscription = visualizationProvider.subscribe(
            VisualizationSubscriptionConfig.latest('subscriptionId'),
          );

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(id: 'unrelatedId', values: [double.nan]),
                testVisualizationItem(id: 'subscriptionId', values: [0.5]),
              ],
            ),
          );

          expect(subscription.readValue(), 0.5);
          expect(subscription.readValues(), [0.5]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(
                  id: 'subscriptionId',
                  values: [123.0, 0.6, 0.7, 0.8],
                ),
              ],
            ),
          );

          expect(subscription.readValue(), 0.8);
          expect(subscription.readValues(), [0.8]);

          break;
        case VisualizationSubscriptionType.max:
          final subscription = visualizationProvider.subscribe(
            VisualizationSubscriptionConfig.max('subscriptionId'),
          );

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(id: 'unrelatedId', values: [double.nan]),
                testVisualizationItem(id: 'subscriptionId', values: [0.5]),
              ],
            ),
          );

          expect(subscription.readValue(), 0.5);
          expect(subscription.readValues(), [0.5]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(
                  id: 'subscriptionId',
                  values: [123.0, 0.6, 0.7, 0.8],
                ),
              ],
            ),
          );

          expect(subscription.readValue(), 123.0);
          expect(subscription.readValues(), [123.0]);

          // If we read the value again, it should be the same as the last read

          expect(subscription.readValue(), 123.0);
          expect(subscription.readValues(), [123.0]);

          // If there are two updates before we read the value again, it should
          // be the maximum across the two updates

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(id: 'subscriptionId', values: [0.9, 1.0]),
              ],
            ),
          );

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(
                  id: 'subscriptionId',
                  values: [0.6, 0.7, 0.8],
                ),
              ],
            ),
          );

          expect(subscription.readValue(), 1.0);
          expect(subscription.readValues(), [1.0]);

          // If we read the value again, it should be the same as the last read

          expect(subscription.readValue(), 1.0);
          expect(subscription.readValues(), [1.0]);

          break;
        case VisualizationSubscriptionType.lastNValues:
          final subscription = visualizationProvider.subscribe(
            VisualizationSubscriptionConfig.lastNValues('subscriptionId', 3),
          );

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(id: 'unrelatedId', values: [double.nan]),
                testVisualizationItem(id: 'subscriptionId', values: [0.5]),
              ],
            ),
          );

          expect(subscription.readValues(), [0.5]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(id: 'subscriptionId', values: [0.6]),
              ],
            ),
          );

          expect(subscription.readValues(), [0.6]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(id: 'subscriptionId', values: [0.7, 0.8]),
              ],
            ),
          );

          expect(subscription.readValues(), [0.7, 0.8]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(id: 'subscriptionId', values: [0.9, 1.0]),
              ],
            ),
          );

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                testVisualizationItem(id: 'subscriptionId', values: [1.1, 1.2]),
              ],
            ),
          );

          expect(subscription.readValues(), [1.0, 1.1, 1.2]);

          break;
      }
    }
  });

  test('String reads only expose native string subscriptions', () {
    final visualizationApiMock = MockVisualizationApi();

    final engineMock = MockEngine();
    when(engineMock.visualizationApi).thenReturn(visualizationApiMock);
    when(engineMock.audioConfig).thenReturn(testAudioConfig());

    final projectMock = MockProjectModel();
    when(projectMock.engine).thenReturn(engineMock);

    final visualizationProvider = VisualizationProvider(projectMock);

    final latestString = visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.latest('string_latest'),
    );
    final bufferedString = visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.lastNValues('string_buffered', 3),
    );
    final latestDouble = visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.latest('double_latest'),
    );

    visualizationProvider.processVisualizationUpdate(
      VisualizationUpdateEvent(
        id: 0,
        items: [
          testVisualizationItem(
            id: 'string_latest',
            values: ['alpha'],
            sampleTimestamps: [11],
          ),
          testVisualizationItem(
            id: 'string_buffered',
            values: ['beta', 'gamma'],
            sampleTimestamps: [21, 31],
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
    expect(bufferedString.readValuesString(), ['beta', 'gamma']);
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
    expect(bufferedString.readTimedValuesString().toList(growable: false), [
      isA<TimedVisualizationValue<String>>()
          .having((value) => value.value, 'value', 'beta')
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(21),
          ),
      isA<TimedVisualizationValue<String>>()
          .having((value) => value.value, 'value', 'gamma')
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(31),
          ),
    ]);

    latestString.setOverride(
      valueString: 'override',
      duration: const Duration(seconds: 1),
    );
    expect(latestString.readValueString(), 'override');
    expect(latestString.readTimedValueString(), isNull);

    expect(() => latestDouble.readValueString(), throwsA(isA<StateError>()));
    expect(
      () => latestDouble.readValuesString().toList(growable: false),
      throwsA(isA<StateError>()),
    );
    expect(
      () => latestDouble.readTimedValueString(),
      throwsA(isA<StateError>()),
    );
    expect(
      () => latestDouble.readTimedValuesString().toList(growable: false),
      throwsA(isA<StateError>()),
    );
  });

  test('Timed reads expose engine sample timestamps', () {
    final visualizationApiMock = MockVisualizationApi();

    final engineMock = MockEngine();
    when(engineMock.visualizationApi).thenReturn(visualizationApiMock);
    when(engineMock.audioConfig).thenReturn(testAudioConfig());

    final projectMock = MockProjectModel();
    when(projectMock.engine).thenReturn(engineMock);

    final visualizationProvider = VisualizationProvider(projectMock);

    final latest = visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.latest('latest'),
    );
    final max = visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.max('max'),
    );
    final buffered = visualizationProvider.subscribe(
      const VisualizationSubscriptionConfig.lastNValues('buffered', 3),
    );

    visualizationProvider.processVisualizationUpdate(
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
          testVisualizationItem(
            id: 'buffered',
            values: [3.0, 4.0],
            sampleTimestamps: [170, 190],
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
    expect(buffered.readTimedValues().toList(growable: false), [
      isA<TimedVisualizationValue<double>>()
          .having((value) => value.value, 'value', 3.0)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(170),
          ),
      isA<TimedVisualizationValue<double>>()
          .having((value) => value.value, 'value', 4.0)
          .having(
            (value) => value.engineTime,
            'engineTime',
            engineTimeForSampleTimestamp(190),
          ),
    ]);
  });

  test(
    'Timed reads return nothing before engine data and while overrides are active',
    () {
      final visualizationApiMock = MockVisualizationApi();

      final engineMock = MockEngine();
      when(engineMock.visualizationApi).thenReturn(visualizationApiMock);
      when(engineMock.audioConfig).thenReturn(testAudioConfig());

      final projectMock = MockProjectModel();
      when(projectMock.engine).thenReturn(engineMock);

      final visualizationProvider = VisualizationProvider(projectMock);

      final latest = visualizationProvider.subscribe(
        const VisualizationSubscriptionConfig.latest('latest'),
      );

      expect(latest.readTimedValue(), isNull);
      expect(latest.readTimedValues(), isEmpty);

      visualizationProvider.processVisualizationUpdate(
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

      latest.setOverride(
        valueDouble: 9.0,
        duration: const Duration(seconds: 1),
      );

      expect(latest.readValue(), 9.0);
      expect(latest.readTimedValue(), isNull);
      expect(latest.readTimedValues(), isEmpty);
    },
  );

  test(
    'Visualization updates reject mismatched value and timestamp counts',
    () {
      final visualizationApiMock = MockVisualizationApi();

      final engineMock = MockEngine();
      when(engineMock.visualizationApi).thenReturn(visualizationApiMock);
      when(engineMock.audioConfig).thenReturn(testAudioConfig());

      final projectMock = MockProjectModel();
      when(projectMock.engine).thenReturn(engineMock);

      final visualizationProvider = VisualizationProvider(projectMock);
      visualizationProvider.subscribe(
        const VisualizationSubscriptionConfig.latest('subscriptionId'),
      );

      final malformedItem = VisualizationItem.uninitialized()
        ..id = 'subscriptionId'
        ..values = [1.0, 2.0]
        ..sampleTimestamps = [10];

      expect(
        () => visualizationProvider.processVisualizationUpdate(
          VisualizationUpdateEvent(id: 0, items: [malformedItem]),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('Visualization updates are correct', () async {
    final visualizationApiMock = MockVisualizationApi();

    final engineMock = MockEngine();
    when(engineMock.visualizationApi).thenReturn(visualizationApiMock);
    when(engineMock.audioConfig).thenReturn(testAudioConfig());

    final projectMock = MockProjectModel();
    when(projectMock.engine).thenReturn(engineMock);

    final visualizationProvider = VisualizationProvider(projectMock);

    StreamController<List<String>> setSubscriptionsController =
        StreamController<List<String>>.broadcast();

    Future<void> assertNoSubscriptionChanges() async {
      bool timeout = false;

      await setSubscriptionsController.stream.first.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {
          timeout = true;
          return [];
        },
      );

      if (!timeout) {
        fail('Expected no subscription changes, but got some.');
      }
    }

    Future<List<String>> getNextSubscriptionChanges() async {
      final keys = await setSubscriptionsController.stream.first.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {
          fail('Expected subscription changes, but got none.');
        },
      );
      return keys;
    }

    when(visualizationApiMock.setSubscriptions(any)).thenAnswer((invocation) {
      final keys = invocation.positionalArguments[0] as List<String>;
      setSubscriptionsController.add(keys);
    });

    final subscription1 = visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latest('subscriptionId1'),
    );
    final subscription2 = visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latest('subscriptionId2'),
    );

    expect(
      await getNextSubscriptionChanges(),
      containsAll(['subscriptionId1', 'subscriptionId2']),
    );

    final subscription3 = visualizationProvider.subscribe(
      VisualizationSubscriptionConfig.latest('subscriptionId3'),
    );

    expect(
      await getNextSubscriptionChanges(),
      containsAll(['subscriptionId1', 'subscriptionId2', 'subscriptionId3']),
    );

    final subscriptionDuplicate = visualizationProvider.subscribe(
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
  });

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
    },
  );
}
