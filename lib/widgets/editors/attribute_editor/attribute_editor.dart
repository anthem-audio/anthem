/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/attribute_editor/attribute_group.dart';
import 'package:flutter/widgets.dart';

class AttributeEditor extends StatelessWidget {
  const AttributeEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AnthemTheme.panel.backgroundDark,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            AttributeGroup(title: 'Arranger clip'),
          ],
        ),
      ),
    );
  }
}
