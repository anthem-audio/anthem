/*
  Copyright (C) 2022 - 2023 Joshua Wade

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
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class TrackHeader extends StatelessObserverWidget {
  final Id trackID;

  const TrackHeader({super.key, required this.trackID});

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final track = project.tracks[trackID]!;

    final trackAnthemColor = track.color;
    final colorShifter = trackAnthemColor.colorShifter;
    final color = colorShifter.clipBase.toColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: AnthemTheme.panel.main,
          child: Row(
            children: [
              Container(
                width: 9,
                decoration: BoxDecoration(
                  color: color,
                  border: Border(
                    right: BorderSide(
                      color: AnthemTheme.panel.border,
                      width: 1,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        track.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AnthemTheme.text.main,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
