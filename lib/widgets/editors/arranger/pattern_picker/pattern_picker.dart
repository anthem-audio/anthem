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

import 'package:anthem/widgets/basic/clip/clip.dart' as anthem_clip;
import 'package:anthem/widgets/basic/clip/clip_cubit.dart';
import 'package:anthem/widgets/editors/arranger/pattern_picker/pattern_picker_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../theme.dart';
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
                    // clipBehavior: Clip.antiAlias,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: state.patterns
                              .map(
                                (pattern) => Padding(
                                  padding: const EdgeInsets.only(bottom: 1),
                                  child: SizedBox(
                                    height: 44,
                                    child: BlocProvider(
                                      create: (context) {
                                        return ClipCubit(
                                          projectID: state.projectID,
                                          patternID: pattern.id,
                                        );
                                      },
                                      child: anthem_clip.Clip(),
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
                Scrollbar(
                  controller: scrollController,
                  crossAxisSize: 17,
                  direction: ScrollbarDirection.vertical,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
