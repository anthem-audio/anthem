/*
  Copyright (C) 2023 Joshua Wade

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

part of 'package:anthem/model/pattern/pattern.dart';

mixin _ClipNotesRenderCacheMixin on _PatternModel {
  // When generators can be removed, removing a generator should clear the
  // associated item in this map.
  final clipNotesRenderCache = <Id, ClipNotesRenderCache>{};

  /// This is crude, but it allows us to signal changes in the
  /// ClipNotesRenderCache without needing to tangle MobX with that object.
  final Observable<int> clipNotesUpdateSignal = Observable(0);

  late final Action incrementClipUpdateSignal;

  void updateClipNotesRenderCache() {
    for (final generatorID in project.generatorOrder) {
      clipNotesRenderCache[generatorID] ??= ClipNotesRenderCache(
        pattern: this as PatternModel,
        generatorID: generatorID,
      );
      clipNotesRenderCache[generatorID]!.update();
    }
    incrementClipUpdateSignal();
  }

  bool _cacheUpdateScheduled = false;

  /// Schedules a call to updateClipNotesRenderCache on the next async break, if
  /// one hasn't already been scheduled.
  void scheduleClipNotesRenderCacheUpdate() {
    if (_cacheUpdateScheduled) return;

    _cacheUpdateScheduled = true;
    scheduleMicrotask(() {
      _cacheUpdateScheduled = false;
      updateClipNotesRenderCache();
    });
  }
}
