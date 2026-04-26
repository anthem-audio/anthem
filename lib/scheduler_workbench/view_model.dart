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

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'view_model.g.dart';

const workbenchMinZoom = 0.05;
const workbenchMaxZoom = 1.0;

// ignore: library_private_types_in_public_api
class WorkbenchViewModel = _WorkbenchViewModel with _$WorkbenchViewModel;

abstract class _WorkbenchViewModel with Store {
  @observable
  double zoom = workbenchMinZoom;

  @observable
  Offset viewportOffset = Offset.zero;

  @action
  void panBy(Offset screenDelta) {
    viewportOffset += screenDelta;
  }

  @action
  void zoomAt({
    required Offset localFocalPoint,
    required Offset viewportCenter,
    required double scaleFactor,
  }) {
    setZoomAt(
      localFocalPoint: localFocalPoint,
      viewportCenter: viewportCenter,
      newZoom: zoom * scaleFactor,
    );
  }

  @action
  void setZoomAt({
    required Offset localFocalPoint,
    required Offset viewportCenter,
    required double newZoom,
  }) {
    final oldZoom = zoom;
    final clampedZoom = newZoom
        .clamp(workbenchMinZoom, workbenchMaxZoom)
        .toDouble();
    final worldFocalPoint =
        (localFocalPoint - viewportCenter - viewportOffset) / oldZoom;

    zoom = clampedZoom;
    viewportOffset =
        localFocalPoint - viewportCenter - worldFocalPoint * clampedZoom;
  }

  @action
  void setZoomAtCenter({
    required Offset viewportCenter,
    required double newZoom,
  }) {
    setZoomAt(
      localFocalPoint: viewportCenter,
      viewportCenter: viewportCenter,
      newZoom: newZoom,
    );
  }
}
