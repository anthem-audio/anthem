/*
  Copyright (C) 2021 Joshua Wade

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

import 'dart:ui';
import 'package:anthem/helpers/get_id.dart';

abstract class GeneratorModel {
  int id;
  String name;
  Color color;

  GeneratorModel({
    required this.name,
    required this.color,
  }) : id = getID();
}

class InstrumentModel extends GeneratorModel {
  InstrumentModel({
    required String name,
    required Color color,
  }) : super(name: name, color: color);
}

class ControllerModel extends GeneratorModel {
  ControllerModel({
    required String name,
    required Color color,
  }) : super(name: name, color: color);
}
