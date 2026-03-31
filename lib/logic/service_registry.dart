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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/track_controller.dart';
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

typedef ServiceFactory<T extends Object> =
    T Function(ProjectModel project, ServiceRegistry registry);

class ServiceDef<T extends Object> {
  final ServiceFactory<T> create;
  final int disposePriority;

  const ServiceDef({required this.create, this.disposePriority = 0});
}

class ProjectServiceOverride<T extends Object> {
  final ServiceDef<T> service;
  final ServiceFactory<T> factory;

  const ProjectServiceOverride(this.service, this.factory);
}

ProjectServiceOverride<T> overrideService<T extends Object>(
  ServiceDef<T> service,
  ServiceFactory<T> factory,
) => ProjectServiceOverride(service, factory);

final idAllocatorService = ServiceDef<ProjectEntityIdAllocator>(
  create: (project, _) => project.idAllocator,
);

final projectViewModelService = ServiceDef<ProjectViewModel>(
  create: (_, _) => ProjectViewModel(),
);

final projectControllerService = ServiceDef<ProjectController>(
  create: (project, registry) =>
      ProjectController(project, registry.use(projectViewModelService)),
  disposePriority: 100,
);

final trackControllerService = ServiceDef<TrackController>(
  create: (project, _) => TrackController(project),
  disposePriority: 100,
);

final arrangerViewModelService = ServiceDef<ArrangerViewModel>(
  create: (project, _) => ArrangerViewModel(
    project: project,
    baseTrackHeight: 53,
    timeView: TimeRange(0, 3072),
  ),
);

final arrangerControllerService = ServiceDef<ArrangerController>(
  create: (project, registry) => ArrangerController(
    viewModel: registry.use(arrangerViewModelService),
    project: project,
  ),
  disposePriority: 100,
);

final pianoRollViewModelService = ServiceDef<PianoRollViewModel>(
  create: (_, _) => PianoRollViewModel(
    keyHeight: 14.0,
    keyValueAtTop: 63.95,
    timeView: TimeRange(0, 3072),
  ),
);

final pianoRollControllerService = ServiceDef<PianoRollController>(
  create: (project, registry) => PianoRollController(
    project: project,
    viewModel: registry.use(pianoRollViewModelService),
  ),
  disposePriority: 100,
);

final automationEditorViewModelService = ServiceDef<AutomationEditorViewModel>(
  create: (_, _) => AutomationEditorViewModel(timeView: TimeRange(0, 3072)),
);

final automationEditorControllerService =
    ServiceDef<AutomationEditorController>(
      create: (project, registry) => AutomationEditorController(
        viewModel: registry.use(automationEditorViewModelService),
        project: project,
      ),
      disposePriority: 100,
    );

class ProjectServiceFactoryOverrides {
  static const empty = ProjectServiceFactoryOverrides._(<Object, Object>{});

  final Map<Object, Object> _factories;

  factory ProjectServiceFactoryOverrides([
    Iterable<ProjectServiceOverride<dynamic>> overrides = const [],
  ]) {
    final factories = <Object, Object>{};

    for (final override in overrides) {
      factories[override.service] = override.factory;
    }

    return ProjectServiceFactoryOverrides._(Map.unmodifiable(factories));
  }

  const ProjectServiceFactoryOverrides._(this._factories);

  bool get isEmpty => _factories.isEmpty;

  ServiceFactory<T>? factoryFor<T extends Object>(ServiceDef<T> service) {
    final factory = _factories[service];
    if (factory == null) {
      return null;
    }

    return factory as ServiceFactory<T>;
  }
}

class ServiceRegistry {
  static final MainWindowController mainWindowController =
      MainWindowController();
  static final MainWindowViewModel mainWindowViewModel = MainWindowViewModel();
  static final DialogController dialogController = DialogController();
  static late final ScreenOverlayController screenOverlayController;

  static final Map<ProjectId, ServiceRegistry> _serviceRegistriesByProjectId =
      {};

  static ServiceRegistry initializeProject(
    ProjectModel project, {
    ProjectServiceFactoryOverrides overrides =
        ProjectServiceFactoryOverrides.empty,
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

  static ServiceRegistry? maybeForProject(ProjectId projectId) =>
      _serviceRegistriesByProjectId[projectId];

  static ServiceRegistry forProject(ProjectId projectId) {
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
  static void removeProject(ProjectId projectId) {
    final serviceRegistry = _serviceRegistriesByProjectId[projectId];
    if (serviceRegistry == null) {
      return;
    }

    serviceRegistry._dispose();
    _serviceRegistriesByProjectId.remove(projectId);
  }

  ProjectController get projectController => use(projectControllerService);
  TrackController get trackController => use(trackControllerService);
  ProjectEntityIdAllocator get idAllocator => use(idAllocatorService);
  ArrangerController get arrangerController => use(arrangerControllerService);
  PianoRollController get pianoRollController =>
      use(pianoRollControllerService);
  AutomationEditorController get automationEditorController =>
      use(automationEditorControllerService);

  ProjectViewModel get projectViewModel => use(projectViewModelService);
  ArrangerViewModel get arrangerViewModel => use(arrangerViewModelService);
  PianoRollViewModel get pianoRollViewModel => use(pianoRollViewModelService);
  AutomationEditorViewModel get automationEditorViewModel =>
      use(automationEditorViewModelService);

  final ProjectModel project;
  final ProjectServiceFactoryOverrides _overrides;

  ServiceRegistry._internal(this.project, this._overrides);

  final Map<(Type, Object?), _RegisteredService> _services = {};
  int _nextServiceRegistrationOrder = 0;

  void _dispose() {
    final disposedServices = <Object>[];
    final services = _services.values.toList(growable: false)
      ..sort((a, b) {
        final priorityComparison = b.disposePriority.compareTo(
          a.disposePriority,
        );
        if (priorityComparison != 0) {
          return priorityComparison;
        }

        return b.registrationOrder.compareTo(a.registrationOrder);
      });

    for (final entry in services) {
      final service = entry.instance;
      if (service is DisposableService &&
          !disposedServices.any((disposed) => identical(disposed, service))) {
        service.dispose();
        disposedServices.add(service);
      }
    }

    _services.clear();
  }

  T use<T extends Object>(ServiceDef<T> service, [Object? key]) {
    final existingService = get<T>(key);
    if (existingService != null) {
      return existingService;
    }

    final createdService =
        _overrides.factoryFor(service)?.call(project, this) ??
        service.create(project, this);
    _register<T>(createdService, key, service.disposePriority);
    return createdService;
  }

  void register<T>(T controller, [Object? key]) {
    if (T == dynamic) {
      throw Exception('Cannot register controller of type dynamic');
    }

    _register<T>(controller, key);
  }

  void _register<T>(T controller, [Object? key, int disposePriority = 0]) {
    _services[(T, key)] = _RegisteredService(
      instance: controller as Object,
      disposePriority: disposePriority,
      registrationOrder: _nextServiceRegistrationOrder++,
    );
  }

  T? get<T>([Object? key]) {
    if (T == dynamic) {
      throw Exception('Cannot get controller of type dynamic');
    }

    final controller = _services[(T, key)]?.instance;
    if (controller is T) {
      return controller;
    }
    return null;
  }

  void unregister<T>([Object? key]) {
    if (T == dynamic) {
      throw Exception('Cannot unregister controller of type dynamic');
    }

    _services.remove((T, key));
  }
}

class _RegisteredService {
  final Object instance;
  final int disposePriority;
  final int registrationOrder;

  const _RegisteredService({
    required this.instance,
    required this.disposePriority,
    required this.registrationOrder,
  });
}
