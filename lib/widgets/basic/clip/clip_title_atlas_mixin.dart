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

part of 'package:anthem/model/sequence.dart';

mixin _ClipTitleAtlasMixin on _SequenceModel {
  @hide
  bool isClipTitleTextureAtlasUpdateScheduled = false;

  @hide
  PackedTexture patternTitleTexture = PackedTexture();

  void scheduleClipTitleTextureAtlasUpdate() {
    if (isClipTitleTextureAtlasUpdateScheduled) {
      return;
    }
    isClipTitleTextureAtlasUpdateScheduled = true;
    Future.microtask(() {
      _updateClipTitleTextureAtlas();
      isClipTitleTextureAtlasUpdateScheduled = false;
    });
  }

  void _updateClipTitleTextureAtlas() {
    final patternIds = patternOrder
        .where((patternID) => patterns[patternID]?.renderedTitle != null)
        .toList();
    final images = patternIds
        .map((patternID) => patterns[patternID]!.renderedTitle!)
        .toList();

    final rects = patternTitleTexture.drawImages(images);

    for (var i = 0; i < patternIds.length; i++) {
      final patternID = patternIds[i];
      final pattern = patterns[patternID]!;
      pattern.clipTitleAtlasRect = rects[i];
    }
  }
}
