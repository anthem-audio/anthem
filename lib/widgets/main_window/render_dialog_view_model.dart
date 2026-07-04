/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:mobx/mobx.dart';

part 'render_dialog_view_model.g.dart';

enum RenderDialogRangeMode { project, loop }

// ignore: library_private_types_in_public_api
class RenderDialogViewModel = _RenderDialogViewModel
    with _$RenderDialogViewModel;

abstract class _RenderDialogViewModel with Store {
  final ProjectId projectId;

  @observable
  String filePath;

  @observable
  RenderAudioFormat format;

  @observable
  int sampleRate;

  @observable
  int wavBitDepth = 32;

  @observable
  RenderAudioSampleFormat wavSampleFormat =
      RenderAudioSampleFormat.floatingPoint;

  @observable
  int aiffBitDepth = 24;

  @observable
  int flacBitDepth = 24;

  @observable
  int flacCompressionLevel = 5;

  @observable
  int oggQualityOptionIndex = 9;

  @observable
  RenderDialogRangeMode rangeMode = RenderDialogRangeMode.project;

  @observable
  bool includeTail = true;

  @observable
  String statusText = '';

  _RenderDialogViewModel({
    required this.projectId,
    required this.filePath,
    required this.format,
    required this.sampleRate,
  });

  bool get hasFilePath => filePath.trim().isNotEmpty;
}
