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

import 'dart:math';

import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/project_details/time_signature_change_detail_view_cubit.dart';
import 'package:anthem/widgets/project_details/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class TimeSignatureChangeDetailView extends StatelessWidget {
  const TimeSignatureChangeDetailView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimeSignatureChangeDetailViewCubit,
        TimeSignatureChangeDetailViewState>(
      builder: (context, state) {
        final cubit = Provider.of<TimeSignatureChangeDetailViewCubit>(context);

        return Column(
          children: [
            Section(
              title: "TIME SIGNATURE CHANGE",
              children: [
                Dropdown(
                  height: 26,
                  allowNoSelection: false,
                  selectedID: state.numerator.toString(),
                  items: List.generate(
                    32,
                    (index) => DropdownItem(
                      id: (index + 1).toString(),
                      name: (index + 1).toString(),
                    ),
                  ),
                  onChanged: (id) {
                    cubit.setNumerator(int.parse(id!));
                  },
                ),
                const SizedBox(height: 4),
                Dropdown(
                  height: 26,
                  allowNoSelection: false,
                  selectedID: state.denominator.toString(),
                  items: List.generate(
                    6,
                    (index) {
                      final value = pow(2, index).toString();
                      return DropdownItem(id: value, name: value);
                    },
                  ),
                  onChanged: (id) {
                    cubit.setDenominator(int.parse(id!));
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Expanded(child: SizedBox()),
          ],
        );
      },
    );
  }
}
