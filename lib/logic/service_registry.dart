/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/main_window/main_window_view_model.dart';
import 'package:anthem/widgets/project/project_view_model.dart';

/// A registry for storing and retrieving services by key.
///
/// Unless otherwise necessary, services are registered here by project ID. For
/// example, the arranger controller for each project is just registered under
/// that project's ID.
class ServiceRegistry {
  static final MainWindowController mainWindowController =
      MainWindowController();
  static final MainWindowViewModel mainWindowViewModel = MainWindowViewModel();
  static final DialogController dialogController = DialogController();

  static final Map<Id, ServiceRegistry> _serviceRegistriesByProjectId = {};

  static ServiceRegistry forProject(Id projectId) =>
      _serviceRegistriesByProjectId[projectId] ??= ServiceRegistry._internal();
  static void removeProject(Id projectId) =>
      _serviceRegistriesByProjectId.remove(projectId);

  ProjectController get projectController =>
      _services[(ProjectController, null)]!;
  ArrangerController get arrangerController =>
      _services[(ArrangerController, null)]!;

  ProjectViewModel get projectViewModel => _services[(ProjectViewModel, null)]!;
  ArrangerViewModel get arrangerViewModel =>
      _services[(ArrangerViewModel, null)]!;

  ServiceRegistry._internal();

  final Map<(Type, String?), dynamic> _services = {};

  void register<T>(T controller, [String? key]) {
    if (T == dynamic) {
      throw Exception('Cannot register controller of type dynamic');
    }

    _services[(T, key)] = controller;
  }

  T? get<T>(String key) {
    if (T == dynamic) {
      throw Exception('Cannot get controller of type dynamic');
    }

    final controller = _services[(T, key)];
    if (controller is T) {
      return controller;
    }
    return null;
  }

  void unregister<T>(String key) {
    if (T == dynamic) {
      throw Exception('Cannot unregister controller of type dynamic');
    }

    _services.remove((T, key));
  }
}
