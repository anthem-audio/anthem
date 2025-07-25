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

int _idGen = 0;
int _getId() {
  _idGen = (_idGen + 1) % 1000000;
  return _idGen;
}

class HintSection {
  final String action;
  final String text;

  HintSection(this.action, this.text);
}

/// Store for managing hints.
///
/// This class allows any widget to submit hint text to be displayed by as a
/// hint in the project footer.
class HintStore {
  HintStore._();
  static final HintStore instance = HintStore._();

  /// A list of hints.
  ///
  /// We only display the most recent hint, but we keep a list of all hints.
  /// This is so that if a hint is added while another hint is being displayed,
  /// we don't lose the previous hint, and we can restore it if the new hint is
  /// removed.
  final List<(int, List<HintSection>)> _hints = [];

  int addHint(List<HintSection> sections) {
    final id = _getId();
    _hints.add((id, sections));
    _hintStreamController.add(getActiveHint());
    return id;
  }

  void removeHint(int id) {
    _hints.removeWhere((element) => element.$1 == id);
    _hintStreamController.add(getActiveHint());
  }

  void updateHint(int id, List<HintSection> sections) {
    final index = _hints.indexWhere((element) => element.$1 == id);
    if (index != -1) {
      _hints[index] = (id, sections);
      _hintStreamController.add(getActiveHint());
    }
  }

  List<HintSection>? getActiveHint() {
    if (_hints.isEmpty) return null;
    // Return the most recent hint
    return _hints.last.$2;
  }

  final StreamController<List<HintSection>?> _hintStreamController =
      StreamController<List<HintSection>?>.broadcast();
  Stream<List<HintSection>?> get hintStream => _hintStreamController.stream;
}
