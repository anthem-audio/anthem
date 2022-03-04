/*
  Copyright (C) 2022 Joshua Wade

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

import '../../basic/button.dart';
import '../../basic/icon.dart';

class Arranger extends StatelessWidget {
  const Arranger({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 300,
        child: GridView.count(
          crossAxisCount: 2,
          children: [
            Center(
              child: Button(
                variant: ButtonVariant.light,
                text: "Light",
                startIcon: Icons.hamburger,
              ),
            ),
            Center(
              child: Button(
                variant: ButtonVariant.dark,
                text: "Dark",
                startIcon: Icons.hamburger,
              ),
            ),
            Center(
              child: Button(
                variant: ButtonVariant.label,
                text: "Label",
                startIcon: Icons.hamburger,
                endIcon: Icons.kebab,
              ),
            ),
            Center(
              child: Button(
                width: 120,
                variant: ButtonVariant.ghost,
                text: "Ghost",
                startIcon: Icons.hamburger,
                endIcon: Icons.kebab,
              ),
            ),
            Center(
              child: Button(
                variant: ButtonVariant.ghost,
                startIcon: Icons.kebab,
              ),
            ),
            Center(
              child: Button(
                variant: ButtonVariant.ghost,
                startIcon: Icons.kebab,
                width: 50,
                height: 40,
                showMenuIndicator: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
