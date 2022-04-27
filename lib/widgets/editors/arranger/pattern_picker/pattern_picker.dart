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

import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_tabs.dart';
import 'package:anthem/widgets/basic/clip/clip.dart' as anthem_clip;
import 'package:anthem/widgets/basic/clip/clip_cubit.dart';
import 'package:anthem/widgets/basic/controls/vertical_scale_control.dart';
import 'package:anthem/widgets/editors/arranger/pattern_picker/pattern_picker_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../theme.dart';
import '../../../basic/icon.dart';
import '../../../basic/scroll/scrollbar.dart';

class PatternPicker extends StatelessWidget {
  final ScrollController scrollController = ScrollController();

  PatternPicker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatternPickerCubit, PatternPickerState>(
      builder: (context, state) {
        return NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (notification) {
            WidgetsBinding.instance?.addPostFrameCallback((_) {
              scrollController.position.notifyListeners();
            });
            return true;
          },
          child: SizeChangedLayoutNotifier(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 26,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        child: ButtonTabs(),
                      ),
                      const SizedBox(width: 4),
                      VerticalScaleControl(
                        min: 25,
                        max: 60,
                        value: state.patternHeight,
                        onChange: (value) {
                          final cubit = context.read<PatternPickerCubit>();
                          cubit.setPatternHeight(value);
                          scrollController.position.notifyListeners();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Theme.panel.border,
                              width: 1,
                            ),
                            color: Theme.panel.accentDark,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: state.patternIDs
                                    .map(
                                      (patternID) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 1),
                                        child: SizedBox(
                                          height: state.patternHeight,
                                          child: BlocProvider(
                                            create: (context) {
                                              return ClipCubit.fromPatternID(
                                                projectID: state.projectID,
                                                patternID: patternID,
                                              );
                                            },
                                            child: const anthem_clip.Clip(ticksPerPixel: 5),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 17,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Scrollbar(
                                controller: scrollController,
                                crossAxisSize: 17,
                                direction: ScrollbarDirection.vertical,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Button(
                              startIcon: Icons.add,
                              height: 17,
                              variant: ButtonVariant.ghost,
                              contentPadding: const EdgeInsets.all(0),
                              onPress: () {
                                final cubit = context.read<PatternPickerCubit>();
                                cubit.addPattern("Pattern");
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
