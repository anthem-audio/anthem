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

import 'dart:math';

import 'package:anthem/widgets/basic/clip/clip_notes.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../theme.dart';
import 'generator_row_cubit.dart';

class GeneratorRow extends StatelessWidget {
  final Color generatorColor = Color.fromARGB(
    255,
    Random().nextInt(255),
    Random().nextInt(255),
    Random().nextInt(255),
  );

  GeneratorRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GeneratorRowCubit, GeneratorRowState>(
        builder: (context, state) {
      return GestureDetector(
        onTap: () {
          BlocProvider.of<ProjectCubit>(context)
              .setActiveInstrumentID(state.generatorID);
        },
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Container(
              //   width: 9,
              //   decoration: BoxDecoration(
              //     borderRadius: const BorderRadius.horizontal(
              //       left: Radius.circular(1),
              //       right: Radius.circular(0),
              //     ),
              //     color: generatorColor,
              //   ),
              // ),
              Expanded(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.panel.border),
                    borderRadius: const BorderRadius.all(Radius.circular(1)),
                    color: Theme.panel.main,
                  ),
                  child: state.notes == null
                      ? const SizedBox()
                      : ClipNotes(
                          notes: state.notes!,
                          timeViewStart: 0,
                          // 1 bar is 100 pxiels, can be tweaked (and should probably be set above?)
                          // TODO: hard-coded ticks-per-beat
                          ticksPerPixel: (96 * 4) / 100,
                          color: generatorColor,
                        ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
