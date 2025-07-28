/*
  Copyright (C) 2025 Joshua Wade

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
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:flutter/widgets.dart';

class HintDisplay extends StatefulWidget {
  const HintDisplay({super.key});

  @override
  State<HintDisplay> createState() => _HintDisplayState();
}

class _HintDisplayState extends State<HintDisplay> {
  @override
  void initState() {
    super.initState();

    HintStore.instance.hintStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 304,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.panel.border),
        color: Theme.panel.accentDark,
      ),
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children:
              HintStore.instance
                  .getActiveHint()
                  ?.map((hint) {
                    return [
                      if (hint.action.isNotEmpty)
                        Text(
                          hint.action.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.text.accent,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (hint.action.isNotEmpty) const SizedBox(width: 6),
                      Text(
                        hint.text,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.text.main,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ];
                  })
                  .expand((e) => e)
                  .toList() ??
              [],
        ),
      ),
    );
  }
}
