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

import 'dart:io';
import 'dart:ui' as ui;

import 'package:args/args.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/debug/widget_test_area.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final launchOptions = _parseLaunchOptionsOrExit(args);
  await pointerLock.ensureInitialized();

  if (!kIsWeb) {
    await windowManager.ensureInitialized();
  }

  runApp(
    WidgetTestbedApp(
      screenshotAndExit: launchOptions.screenshotAndExit,
      initialScreen: launchOptions.initialScreen,
      screenshotOutputPath: launchOptions.screenshotOutputPath,
    ),
  );
}

class _LaunchOptions {
  final bool screenshotAndExit;
  final WidgetTestScreenId initialScreen;
  final String screenshotOutputPath;

  const _LaunchOptions({
    required this.screenshotAndExit,
    required this.initialScreen,
    required this.screenshotOutputPath,
  });
}

ArgParser _buildArgParser() {
  return ArgParser()
    ..addFlag(
      'screenshot',
      abbr: 's',
      help: 'Capture a PNG screenshot after launch, then exit.',
      negatable: false,
    )
    ..addOption(
      'screen',
      abbr: 'c',
      help: 'Initial widget test screen.',
      allowed: WidgetTestScreenId.values.map((screen) => screen.name).toList(),
      defaultsTo: WidgetTestScreenId.button.name,
    )
    ..addOption('output', abbr: 'o', help: 'Output path for screenshot PNG.');
}

_LaunchOptions _parseLaunchOptions(List<String> args) {
  final parser = _buildArgParser();
  final parsed = parser.parse(args);

  final rest = parsed.rest;
  var screenshotAndExit = parsed['screenshot'] as bool;
  var screenValue = parsed['screen'] as String;

  if (rest.isNotEmpty) {
    final positionalScreenshotFlag = _tryParsePositionalScreenshotFlag(
      rest.first,
    );

    if (positionalScreenshotFlag != null) {
      screenshotAndExit = positionalScreenshotFlag;
    } else if (tryParseWidgetTestScreenId(rest.first) != null) {
      screenValue = rest.first;
    } else {
      throw FormatException(
        'Invalid first positional arg "${rest.first}". Use true/false, 1/0, or '
        'a screen name.',
      );
    }
  }

  if (rest.length > 1) {
    screenValue = rest[1];
  }

  final initialScreen = tryParseWidgetTestScreenId(screenValue);
  if (initialScreen == null) {
    throw FormatException(
      'Unknown screen "$screenValue". Allowed: '
      '${WidgetTestScreenId.values.map((screen) => screen.name).join(', ')}',
    );
  }

  final screenshotOutputPath =
      parsed['output'] as String? ??
      _defaultScreenshotPath(initialScreen: initialScreen);

  return _LaunchOptions(
    screenshotAndExit: screenshotAndExit,
    initialScreen: initialScreen,
    screenshotOutputPath: screenshotOutputPath,
  );
}

bool? _tryParsePositionalScreenshotFlag(String value) {
  final normalized = value.trim().toLowerCase();

  const trueValues = {'1', 'true', 'yes', 'y', 'on', 'screenshot', 'capture'};
  const falseValues = {'0', 'false', 'no', 'n', 'off', 'run'};

  if (trueValues.contains(normalized)) {
    return true;
  }

  if (falseValues.contains(normalized)) {
    return false;
  }

  return null;
}

String _defaultScreenshotPath({required WidgetTestScreenId initialScreen}) {
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  return '${Directory.current.path}${Platform.pathSeparator}'
      'widget_testbed_${initialScreen.name}_$timestamp.png';
}

void _printUsage() {
  final parser = _buildArgParser();
  stderr.writeln(
    'Usage: flutter run -t lib/main_testbed.dart --dart-entrypoint-args="<take screenshot>" --dart-entrypoint-args="<screen>"',
  );
  stderr.writeln('');
  stderr.writeln('Supported screens:');
  stderr.writeln(
    WidgetTestScreenId.values.map((screen) => '  - ${screen.name}').join('\n'),
  );
  stderr.writeln('');
  stderr.writeln('Named arguments:');
  stderr.writeln(parser.usage);
}

_LaunchOptions _parseLaunchOptionsOrExit(List<String> args) {
  try {
    return _parseLaunchOptions(args);
  } on ArgParserException catch (e) {
    stderr.writeln('Could not parse args: ${e.message}');
    _printUsage();
    if (!kIsWeb) {
      exit(64);
    }
    rethrow;
  } on FormatException catch (e) {
    stderr.writeln('Invalid args: ${e.message}');
    _printUsage();
    if (!kIsWeb) {
      exit(64);
    }
    rethrow;
  }
}

class WidgetTestbedApp extends StatefulWidget {
  final bool screenshotAndExit;
  final WidgetTestScreenId initialScreen;
  final String screenshotOutputPath;

  const WidgetTestbedApp({
    super.key,
    required this.screenshotAndExit,
    required this.initialScreen,
    required this.screenshotOutputPath,
  });

  @override
  State<WidgetTestbedApp> createState() => _WidgetTestbedAppState();
}

class _WidgetTestbedAppState extends State<WidgetTestbedApp> {
  final GlobalKey _screenshotBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    if (widget.screenshotAndExit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _captureScreenshotAndExit();
      });
    }
  }

  Future<void> _captureScreenshotAndExit() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        _screenshotBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null) {
      stderr.writeln(
        'Could not capture screenshot: repaint boundary not available.',
      );

      if (!kIsWeb) {
        exit(1);
      }

      return;
    }

    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      final pixelRatio = views.isNotEmpty ? views.first.devicePixelRatio : 1.0;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw StateError('Failed to encode screenshot as PNG.');
      }

      final outputFile = File(widget.screenshotOutputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      stdout.writeln('Saved screenshot: ${outputFile.path}');

      if (!kIsWeb) {
        exit(0);
      }
    } catch (e) {
      stderr.writeln('Could not capture screenshot: $e');

      if (!kIsWeb) {
        exit(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anthem Widget Testbed',
      color: AnthemTheme.primary.main,
      theme: ThemeData(
        fontFamily: 'Roboto',
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: AnthemTheme.primary.subtleBorder.withAlpha(50),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AnthemTheme.primary.main,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => KeyboardModifiers(),
          child: RepaintBoundary(
            key: _screenshotBoundaryKey,
            child: WidgetTestArea(initialScreen: widget.initialScreen),
          ),
        ),
      ),
      builder: (context, child) {
        return GestureDetector(
          // Un-focus text boxes when clicking elsewhere
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: child!,
          ),
        );
      },
    );
  }
}
