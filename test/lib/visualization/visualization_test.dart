/*
  Copyright (C) 2025 Joshua Wade

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
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<ProjectModel>(),
  MockSpec<Engine>(),
  MockSpec<VisualizationApi>(),
])
import 'visualization_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Subscription object behavior', () {
    for (final value in VisualizationSubscriptionType.values) {
      final visualizationApiMock = MockVisualizationApi();

      final engineMock = MockEngine();
      when(engineMock.visualizationApi).thenReturn(visualizationApiMock);

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
                VisualizationItem(id: 'unrelatedId', values: [double.nan]),
                VisualizationItem(id: 'subscriptionId', values: [0.5]),
              ],
            ),
          );

          expect(subscription.readValue(), 0.5);
          expect(subscription.readValues(), [0.5]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                VisualizationItem(
                  id: 'subscriptionId',
                  values: [123, 0.6, 0.7, 0.8],
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
                VisualizationItem(id: 'unrelatedId', values: [double.nan]),
                VisualizationItem(id: 'subscriptionId', values: [0.5]),
              ],
            ),
          );

          expect(subscription.readValue(), 0.5);
          expect(subscription.readValues(), [0.5]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                VisualizationItem(
                  id: 'subscriptionId',
                  values: [123, 0.6, 0.7, 0.8],
                ),
              ],
            ),
          );

          expect(subscription.readValue(), 123);
          expect(subscription.readValues(), [123]);

          // If we read the value again, it should be the same as the last read

          expect(subscription.readValue(), 123);
          expect(subscription.readValues(), [123]);

          // If there are two updates before we read the value again, it should
          // be the maximum across the two updates

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                VisualizationItem(id: 'subscriptionId', values: [0.9, 1.0]),
              ],
            ),
          );

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                VisualizationItem(
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
                VisualizationItem(id: 'unrelatedId', values: [double.nan]),
                VisualizationItem(id: 'subscriptionId', values: [0.5]),
              ],
            ),
          );

          expect(subscription.readValues(), [0.5]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                VisualizationItem(id: 'subscriptionId', values: [0.6]),
              ],
            ),
          );

          expect(subscription.readValues(), [0.6]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                VisualizationItem(id: 'subscriptionId', values: [0.7, 0.8]),
              ],
            ),
          );

          expect(subscription.readValues(), [0.7, 0.8]);

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                VisualizationItem(id: 'subscriptionId', values: [0.9, 1.0]),
              ],
            ),
          );

          visualizationProvider.processVisualizationUpdate(
            VisualizationUpdateEvent(
              id: 0,
              items: [
                VisualizationItem(id: 'subscriptionId', values: [1.1, 1.2]),
              ],
            ),
          );

          expect(subscription.readValues(), [1.0, 1.1, 1.2]);

          break;
      }
    }
  });

  test('Visualization updates are correct', () async {
    final visualizationApiMock = MockVisualizationApi();

    final engineMock = MockEngine();
    when(engineMock.visualizationApi).thenReturn(visualizationApiMock);

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
}
