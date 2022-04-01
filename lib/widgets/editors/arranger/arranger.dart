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

import 'package:anthem/widgets/basic/control_mouse_handler.dart';
import 'package:anthem/widgets/editors/arranger/arranger_cubit.dart';
import 'package:anthem/widgets/editors/arranger/pattern_picker/pattern_picker.dart';
import 'package:anthem/widgets/editors/arranger/pattern_picker/pattern_picker_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../theme.dart';
import '../piano_roll/helpers.dart';
import '../shared/helpers/types.dart';
import '../shared/timeline.dart';
import '../shared/timeline_cubit.dart';

class Arranger extends StatefulWidget {
  const Arranger({Key? key}) : super(key: key);

  @override
  State<Arranger> createState() => _ArrangerState();
}

class _ArrangerState extends State<Arranger> {
  double x = 0;
  double y = 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArrangerCubit, ArrangerState>(
      builder: (context, state) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TimeView(0, 3072)),
          ],
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Theme.panel.main,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 26),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: SizedBox(
                            width: 126,
                            child: BlocProvider<PatternPickerCubit>(
                              create: (context) =>
                                  PatternPickerCubit(projectID: state.projectID),
                              child: PatternPicker(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: ArrangerContent(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Actual content view of the arranger (timeline + clips + etc)
class ArrangerContent extends StatelessWidget {
  const ArrangerContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArrangerCubit, ArrangerState>(builder: (context, state) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.panel.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: 130),
                    Container(width: 1, color: Theme.panel.border),
                    Expanded(
                      child: BlocProvider<TimelineCubit>(
                        create: (context) => TimelineCubit(
                          projectID: state.projectID,
                          timelineType: TimelineType.arrangerTimeline,
                        ),
                        child: const Timeline(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: Theme.panel.border),
              Expanded(
                child: Container(
                  color: Theme.panel.accent,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
