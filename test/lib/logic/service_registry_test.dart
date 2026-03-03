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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _DisposableTestService implements DisposableService {
  int disposeCallCount = 0;

  @override
  void dispose() {
    disposeCallCount++;
  }
}

class _NonDisposableTestService {}

void main() {
  test('project-scoped factory overrides are applied on initialization', () {
    final project = ProjectModel()
      ..id = getId()
      ..isHydrated = true;
    final projectViewModel = ProjectViewModel();

    final registry = ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides(
        projectViewModel: (_, _) => projectViewModel,
      ),
    );

    expect(registry.projectViewModel, same(projectViewModel));

    ServiceRegistry.removeProject(project.id);
  });

  test('initializeProject rejects late project-scoped overrides', () {
    final project = ProjectModel()
      ..id = getId()
      ..isHydrated = true;

    ServiceRegistry.initializeProject(project);

    expect(
      () => ServiceRegistry.initializeProject(
        project,
        overrides: ProjectServiceFactoryOverrides(
          projectViewModel: (_, _) => ProjectViewModel(),
        ),
      ),
      throwsStateError,
    );

    ServiceRegistry.removeProject(project.id);
  });

  test('removeProject disposes project services and removes the registry', () {
    final project = ProjectModel()
      ..id = getId()
      ..isHydrated = true;
    final registry = ServiceRegistry.initializeProject(project);
    final disposableService = _DisposableTestService();

    registry.register(disposableService);
    registry.register(_NonDisposableTestService());

    ServiceRegistry.removeProject(project.id);

    expect(disposableService.disposeCallCount, 1);
    expect(ServiceRegistry.maybeForProject(project.id), isNull);

    final recreatedRegistry = ServiceRegistry.initializeProject(project);
    expect(recreatedRegistry, isNot(same(registry)));
    expect(recreatedRegistry.get<_DisposableTestService>(), isNull);
    expect(recreatedRegistry.get<_NonDisposableTestService>(), isNull);

    ServiceRegistry.removeProject(project.id);
  });
}
