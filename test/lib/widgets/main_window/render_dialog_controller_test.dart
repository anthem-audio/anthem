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

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/widgets/main_window/render_dialog_controller.dart';
import 'package:anthem/widgets/main_window/render_dialog_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setFilePath adds the fallback format extension', () {
    final controller = _createController(filePath: '');

    controller.setFilePath(r'C:\renders\mix');

    expect(controller.viewModel.filePath, equals(r'C:\renders\mix.wav'));
    expect(controller.viewModel.format, equals(RenderAudioFormat.wav));
  });

  test('setFilePath updates format from supported extension', () {
    final controller = _createController(filePath: r'C:\renders\mix.wav');

    controller.setFilePath(r'C:\renders\mix.flac');

    expect(controller.viewModel.filePath, equals(r'C:\renders\mix.flac'));
    expect(controller.viewModel.format, equals(RenderAudioFormat.flac));
  });

  test('setFilePath adds the current format extension when missing', () {
    final controller = _createController(
      filePath: r'C:\renders\mix.flac',
      format: RenderAudioFormat.flac,
    );

    controller.setFilePath(r'C:\renders\alternate');

    expect(controller.viewModel.filePath, equals(r'C:\renders\alternate.flac'));
    expect(controller.viewModel.format, equals(RenderAudioFormat.flac));
  });

  test('setFormat replaces the path extension', () {
    final controller = _createController(filePath: r'C:\renders\mix.wav');

    controller.setFormat(RenderAudioFormat.oggVorbis);

    expect(controller.viewModel.filePath, equals(r'C:\renders\mix.ogg'));
    expect(controller.viewModel.format, equals(RenderAudioFormat.oggVorbis));
  });
}

RenderDialogController _createController({
  required String filePath,
  RenderAudioFormat format = RenderAudioFormat.wav,
}) {
  return RenderDialogController(
    viewModel: RenderDialogViewModel(
      projectId: 'project',
      filePath: filePath,
      format: format,
    ),
  );
}
