// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:anthem/engine_api/messages/messages.dart';

import 'scenarios.dart';

Future<void> runAudioLifecycle(
  RuntimeSession session, {
  int Function()? renderedBlocks,
}) async {
  int id() => session.connector.getRequestId();

  Future<AudioProcessingConfigDto> start() async {
    final response = await session.request(StartAudioRequest(id: id()));
    if (response is! StartAudioResponse || !response.success) {
      final reason = response is StartAudioResponse ? response.error : response;
      throw StateError('Audio startup failed: $reason');
    }
    final config = response.audioConfig!;
    check(config.sampleRate > 0, 'Expected a positive audio sample rate');
    check(config.outputChannelCount > 0, 'Expected an audio output');
    check(config.blockSize == 128, 'Expected 128-frame graph blocks');
    return config;
  }

  Future<void> stop() async {
    final response = await session.request(StopAudioRequest(id: id()));
    check(
      response is StopAudioResponse && response.success,
      'Audio stop failed',
    );
  }

  Future<void> waitForBlocks(int? before) async {
    if (renderedBlocks == null) {
      // Allow time for the message thread's first stream health check.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return;
    }
    final deadline = Stopwatch()..start();
    while (renderedBlocks() == before) {
      check(
        deadline.elapsed < const Duration(seconds: 3),
        'The worklet did not render',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  try {
    await session.ready();
    // Stop may arrive before asynchronous worklet preparation completes.
    final pending = session.request(StartAudioRequest(id: id()));
    await stop();
    check(await pending is StartAudioResponse, 'Missing startup completion');

    final before = renderedBlocks?.call();
    final config = await start();
    await waitForBlocks(before);
    final repeated = await start();
    check(
      repeated.sampleRate == config.sampleRate,
      'Repeated start changed the stream',
    );
    await stop();
    await stop();

    final stopped = renderedBlocks?.call();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    check(renderedBlocks?.call() == stopped, 'Rendering continued after stop');

    await start();
    await waitForBlocks(stopped);
    check(
      !session.events.any((event) => event is AudioSessionInvalidatedEvent),
      'The audio backend reported a stream failure',
    );
    await session.close();
  } finally {
    await session.connector.shutdown();
  }
}
