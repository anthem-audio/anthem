/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/clip/clip_notes.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../theme.dart';
import 'generator_row_cubit.dart';

class GeneratorRow extends StatelessWidget {
  const GeneratorRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GeneratorRowCubit, GeneratorRowState>(
        builder: (context, state) {
      final backgroundHoverColor =
          HSLColor.fromColor(state.color).withLightness(0.56).toColor();

      return GestureDetector(
        onTap: () {
          BlocProvider.of<ProjectCubit>(context)
              .setActiveGeneratorID(state.generatorID);
        },
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 127),
                Button(
                  width: 105,
                  height: 26,
                  backgroundColor: state.color,
                  backgroundHoverColor: backgroundHoverColor,
                  backgroundPressColor: backgroundHoverColor,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 22,
                  decoration: BoxDecoration(
                    color: state.color,
                    border: Border.all(color: Theme.panel.border),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.panel.border),
                      borderRadius: const BorderRadius.all(Radius.circular(1)),
                      color: Theme.panel.main,
                    ),
                    child: state.patternID == null
                        ? const SizedBox()
                        : ClipNotes(
                            notes: state.clipNotes,
                            timeViewStart: 0,
                            // 1 bar is 100 pixels, can be tweaked (and should probably be set above?)
                            ticksPerPixel: (state.ticksPerQuarter * 4) / 100,
                            color: state.color,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
