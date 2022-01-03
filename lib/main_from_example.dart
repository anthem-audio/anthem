import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:anthem/flutter_rust_bridge_generated.dart';
import 'package:anthem/off_topic_code.dart';

// Simple Flutter code. If you are not familiar with Flutter, this may sounds a bit long. But indeed
// it is quite trivial and Flutter is just like that. Please refer to Flutter's tutorial to learn Flutter.

const base = 'anthem';
final path = Platform.isWindows
    ? '$base.dll'
    : Platform.isMacOS
        ? 'lib$base.dylib'
        : 'lib$base.so';
late final dylib = Platform.isIOS ? DynamicLibrary.process() : DynamicLibrary.open(path);
late final api = Anthem(dylib);

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Uint8List? exampleImage;
  String? exampleText;

  @override
  void initState() {
    super.initState();
    runPeriodically(_callExampleFfiOne);
    _callExampleFfiTwo();
  }

  @override
  Widget build(BuildContext context) => buildPageUi(
        exampleImage,
        exampleText,
      );

  Future<void> _callExampleFfiOne() async {
    final receivedImage = await api.drawMandelbrot(
        imageSize: Size(width: 50, height: 50), zoomPoint: examplePoint, scale: generateScale(), numThreads: 4);
    if (mounted) setState(() => exampleImage = receivedImage);
  }

  Future<void> _callExampleFfiTwo() async {
    final receivedText = await api.passingComplexStructs(root: createExampleTree());
    if (mounted) setState(() => exampleText = receivedText);
  }
}
