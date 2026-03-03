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
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/automation_editor/controller/automation_editor_controller.dart';
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/main_window/main_window_view_model.dart';
import 'package:anthem/widgets/project/project_view_model.dart';

/// A registry for storing and retrieving services by key.
///
/// Project-scoped controllers and view models are owned here and created lazily
/// on first access. Widgets should consume them from this registry rather than
/// constructing or disposing them directly.
abstract interface class DisposableService {
  void dispose();
}

typedef ProjectControllerFactory =
    ProjectController Function(ProjectModel project, ServiceRegistry registry);
typedef ArrangerControllerFactory =
    ArrangerController Function(ProjectModel project, ServiceRegistry registry);
typedef PianoRollControllerFactory =
    PianoRollController Function(
      ProjectModel project,
      ServiceRegistry registry,
    );
typedef AutomationEditorControllerFactory =
    AutomationEditorController Function(
      ProjectModel project,
      ServiceRegistry registry,
    );
typedef ProjectViewModelFactory =
    ProjectViewModel Function(ProjectModel project, ServiceRegistry registry);
typedef ArrangerViewModelFactory =
    ArrangerViewModel Function(ProjectModel project, ServiceRegistry registry);
typedef PianoRollViewModelFactory =
    PianoRollViewModel Function(ProjectModel project, ServiceRegistry registry);
typedef AutomationEditorViewModelFactory =
    AutomationEditorViewModel Function(
      ProjectModel project,
      ServiceRegistry registry,
    );

class ProjectServiceFactoryOverrides {
  final ProjectControllerFactory? projectController;
  final ArrangerControllerFactory? arrangerController;
  final PianoRollControllerFactory? pianoRollController;
  final AutomationEditorControllerFactory? automationEditorController;
  final ProjectViewModelFactory? projectViewModel;
  final ArrangerViewModelFactory? arrangerViewModel;
  final PianoRollViewModelFactory? pianoRollViewModel;
  final AutomationEditorViewModelFactory? automationEditorViewModel;

  const ProjectServiceFactoryOverrides({
    this.projectController,
    this.arrangerController,
    this.pianoRollController,
    this.automationEditorController,
    this.projectViewModel,
    this.arrangerViewModel,
    this.pianoRollViewModel,
    this.automationEditorViewModel,
  });

  bool get isEmpty =>
      projectController == null &&
      arrangerController == null &&
      pianoRollController == null &&
      automationEditorController == null &&
      projectViewModel == null &&
      arrangerViewModel == null &&
      pianoRollViewModel == null &&
      automationEditorViewModel == null;
}

class ServiceRegistry {
  static final MainWindowController mainWindowController =
      MainWindowController();
  static final MainWindowViewModel mainWindowViewModel = MainWindowViewModel();
  static final DialogController dialogController = DialogController();
  static late final ScreenOverlayController screenOverlayController;

  static final Map<Id, ServiceRegistry> _serviceRegistriesByProjectId = {};

  static ServiceRegistry initializeProject(
    ProjectModel project, {
    ProjectServiceFactoryOverrides overrides =
        const ProjectServiceFactoryOverrides(),
  }) {
    final existingServiceRegistry = _serviceRegistriesByProjectId[project.id];
    if (existingServiceRegistry != null) {
      if (!overrides.isEmpty) {
        throw StateError(
          'Project services for project ${project.id} were already '
          'initialized. Factory overrides must be provided on first '
          'initialization.',
        );
      }

      return existingServiceRegistry;
    }

    return _serviceRegistriesByProjectId[project.id] =
        ServiceRegistry._internal(project, overrides);
  }

  static ServiceRegistry? maybeForProject(Id projectId) =>
      _serviceRegistriesByProjectId[projectId];

  static ServiceRegistry forProject(Id projectId) {
    final existingServiceRegistry = _serviceRegistriesByProjectId[projectId];
    if (existingServiceRegistry != null) {
      return existingServiceRegistry;
    }

    final project = AnthemStore.instance.projects[projectId];
    if (project == null) {
      throw StateError(
        'Project services for project $projectId have not been initialized.',
      );
    }

    return initializeProject(project);
  }

  /// Disposes any project-scoped services that opted into cleanup, then
  /// removes the entire project registry object.
  static void removeProject(Id projectId) {
    final serviceRegistry = _serviceRegistriesByProjectId[projectId];
    if (serviceRegistry == null) {
      return;
    }

    serviceRegistry._dispose();
    _serviceRegistriesByProjectId.remove(projectId);
  }

  ProjectController get projectController => _serviceFor<ProjectController>(
    () =>
        _overrides.projectController?.call(project, this) ??
        ProjectController(project, projectViewModel),
  );
  ArrangerController get arrangerController => _serviceFor<ArrangerController>(
    () =>
        _overrides.arrangerController?.call(project, this) ??
        ArrangerController(viewModel: arrangerViewModel, project: project),
  );
  PianoRollController get pianoRollController =>
      _serviceFor<PianoRollController>(
        () =>
            _overrides.pianoRollController?.call(project, this) ??
            PianoRollController(
              project: project,
              viewModel: pianoRollViewModel,
            ),
      );
  AutomationEditorController get automationEditorController =>
      _serviceFor<AutomationEditorController>(
        () =>
            _overrides.automationEditorController?.call(project, this) ??
            AutomationEditorController(
              viewModel: automationEditorViewModel,
              project: project,
            ),
      );

  ProjectViewModel get projectViewModel => _serviceFor<ProjectViewModel>(
    () =>
        _overrides.projectViewModel?.call(project, this) ?? ProjectViewModel(),
  );
  ArrangerViewModel get arrangerViewModel => _serviceFor<ArrangerViewModel>(
    () =>
        _overrides.arrangerViewModel?.call(project, this) ??
        ArrangerViewModel(
          project: project,
          baseTrackHeight: 53,
          timeView: TimeRange(0, 3072),
        ),
  );
  PianoRollViewModel get pianoRollViewModel => _serviceFor<PianoRollViewModel>(
    () =>
        _overrides.pianoRollViewModel?.call(project, this) ??
        PianoRollViewModel(
          keyHeight: 14.0,
          keyValueAtTop: 63.95,
          timeView: TimeRange(0, 3072),
        ),
  );
  AutomationEditorViewModel get automationEditorViewModel =>
      _serviceFor<AutomationEditorViewModel>(
        () =>
            _overrides.automationEditorViewModel?.call(project, this) ??
            AutomationEditorViewModel(timeView: TimeRange(0, 3072)),
      );

  final ProjectModel project;
  final ProjectServiceFactoryOverrides _overrides;

  ServiceRegistry._internal(this.project, this._overrides);

  final Map<(Type, String?), dynamic> _services = {};

  void _dispose() {
    final disposedServices = <Object>[];

    void disposeRegisteredService<T>([String? key]) {
      final service = get<T>(key);
      if (service is DisposableService) {
        service.dispose();
        disposedServices.add(service);
      }
    }

    // Dispose controllers before clearing any dependent view models.
    disposeRegisteredService<AutomationEditorController>();
    disposeRegisteredService<PianoRollController>();
    disposeRegisteredService<ArrangerController>();
    disposeRegisteredService<ProjectController>();

    final services = _services.values.toList(growable: false);

    for (final service in services) {
      if (service is DisposableService &&
          !disposedServices.any((disposed) => identical(disposed, service))) {
        service.dispose();
      }
    }

    _services.clear();
  }

  T _serviceFor<T>(T Function() create, [String? key]) {
    final existingService = get<T>(key);
    if (existingService != null) {
      return existingService;
    }

    final createdService = create();
    _register<T>(createdService, key);
    return createdService;
  }

  void register<T>(T controller, [String? key]) {
    if (T == dynamic) {
      throw Exception('Cannot register controller of type dynamic');
    }

    _register<T>(controller, key);
  }

  void _register<T>(T controller, [String? key]) {
    _services[(T, key)] = controller;
  }

  T? get<T>([String? key]) {
    if (T == dynamic) {
      throw Exception('Cannot get controller of type dynamic');
    }

    final controller = _services[(T, key)];
    if (controller is T) {
      return controller;
    }
    return null;
  }

  void unregister<T>([String? key]) {
    if (T == dynamic) {
      throw Exception('Cannot unregister controller of type dynamic');
    }

    _services.remove((T, key));
  }
}
