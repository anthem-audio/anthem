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

import 'dart:ui';

const clipTitleHeight = 16.0;
const clipTitlePadding = 2.0;

void drawClipTitleText({
  required Canvas canvas,
  required String title,
  required double x,
  required double y,
  required double width,
  required double devicePixelRatio,
  required Color textColor,
}) {
  final paragraphStyle = ParagraphStyle(textAlign: TextAlign.left, maxLines: 1);

  final paragraphBuilder = ParagraphBuilder(paragraphStyle)
    ..pushStyle(TextStyle(color: textColor, fontSize: 11 * devicePixelRatio))
    ..addText(title);

  final paragraph = paragraphBuilder.build();
  final constraints = ParagraphConstraints(
    width: width - clipTitlePadding * 2 + 2,
  );
  paragraph.layout(constraints);

  canvas.drawParagraph(paragraph, Offset(x + clipTitlePadding + 1, y));
}

(double, double) getClipTitleTextSize({
  required double devicePixelRatio,
  required String title,
}) {
  final paragraphStyle = ParagraphStyle(
    textAlign: TextAlign.left,
    ellipsis: '...',
    maxLines: 1,
  );

  final paragraphBuilder = ParagraphBuilder(paragraphStyle)
    ..pushStyle(TextStyle(fontSize: 11 * devicePixelRatio))
    ..addText(title);

  final paragraph = paragraphBuilder.build();
  const constraints = ParagraphConstraints(width: double.infinity);
  paragraph.layout(constraints);

  final width = paragraph.maxIntrinsicWidth / devicePixelRatio + 6;

  return (width, clipTitleHeight);
}

Future<Image> renderClipTitleImage({
  required String title,
  required double devicePixelRatio,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  final inputWidth = 250.0 * devicePixelRatio;

  drawClipTitleText(
    canvas: canvas,
    title: title,
    x: 3,
    y: 0,
    width: inputWidth,
    devicePixelRatio: devicePixelRatio,
    textColor: const Color(0xFFFFFFFF),
  );

  final picture = recorder.endRecording();
  final (width, height) = getClipTitleTextSize(
    devicePixelRatio: devicePixelRatio,
    title: title,
  );

  return picture.toImage(
    (width * devicePixelRatio).ceil(),
    (height * devicePixelRatio).ceil(),
  );
}
