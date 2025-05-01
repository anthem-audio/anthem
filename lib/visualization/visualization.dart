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

// This module contains the UI portion of Anthem's machinery for streaming live
// data values (e.g. CPU usage, meter levels, transport position) from the
// engine to the UI. It provides a subscription model for the UI to request
// updates for specific data values.

import 'dart:async';
import 'dart:math';

import 'package:anthem/engine_api/messages/messages.dart'
    show VisualizationUpdate;
import 'package:anthem/model/project.dart';

import 'ring_buffer_double.dart';

part 'provider.dart';
part 'subscription.dart';
