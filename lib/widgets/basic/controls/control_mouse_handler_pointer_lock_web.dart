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

import 'package:web/web.dart' as web;

bool get shouldUsePointerLock =>
    allowsPointerLock(web.window.navigator.userAgent);

/// Safari's pointer-lock banner resizes the viewport during control drags.
bool allowsPointerLock(String userAgent) {
  // iOS browsers also use WebKit and should use ordinary dragging. Desktop
  // Chromium browsers include "Safari" in their user agent too.
  final isSafari =
      userAgent.contains('Safari/') &&
      !RegExp(r'Chrome/|Chromium/|Edg/|OPR/|Android').hasMatch(userAgent);
  return !isSafari;
}
