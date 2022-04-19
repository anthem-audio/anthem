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

import 'package:anthem/widgets/editors/arranger/track_header_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../theme.dart';
import '../../basic/button.dart';
import '../../basic/icon.dart';

class TrackHeader extends StatelessWidget {
  const TrackHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackHeaderCubit, TrackHeaderState>(
        builder: (context, state) {
      return LayoutBuilder(builder: (context, constraints) {
        final height = constraints.maxHeight;
        const fontSize = 11.0;

        // Hacky way to make sure it's centered when the row is small
        final double verticalPadding =
            8.0.clamp(0, (height - fontSize - 5) / 2);

        return Container(
            decoration: BoxDecoration(
              color: Theme.panel.accent,
              borderRadius: BorderRadius.circular(1),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 8,
                  top: verticalPadding,
                  child: Text(
                    state.trackName,
                    style: TextStyle(
                      color: Theme.text.main,
                      fontSize: fontSize,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Button(
                    variant: ButtonVariant.label,
                    startIcon: Icons.mute,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: verticalPadding,
                    ),
                    hideBorder: true,
                    toggleState: true,
                  ),
                ),
              ],
            ));
      });
    });
  }
}
