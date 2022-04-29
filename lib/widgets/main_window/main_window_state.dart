/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

part of 'main_window_cubit.dart';

@immutable
class MainWindowState {
  final ID selectedTabID;
  final List<TabDef> tabs;

  const MainWindowState({required this.selectedTabID, required this.tabs});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MainWindowState &&
          other.selectedTabID == selectedTabID &&
          other.tabs == tabs;

  @override
  int get hashCode => selectedTabID.hashCode ^ tabs.hashCode;
}

@immutable
class TabDef {
  final ID id;
  final String title;

  const TabDef({required this.id, required this.title});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabDef && other.id == id && other.title == title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}

class KeyboardModifiers with ChangeNotifier, DiagnosticableTreeMixin {
  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;

  KeyboardModifiers();

  bool get ctrl => _ctrl;
  bool get alt => _alt;
  bool get shift => _shift;

  void setCtrl(bool value) {
    _ctrl = value;
    notifyListeners();
  }

  void setAlt(bool value) {
    _alt = value;
    notifyListeners();
  }

  void setShift(bool value) {
    _shift = value;
    notifyListeners();
  }
}
