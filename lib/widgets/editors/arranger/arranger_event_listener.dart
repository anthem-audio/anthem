/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/widgets/editors/arranger/arranger_view_model.dart';
import 'package:anthem/widgets/editors/shared/scroll_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class ArrangerEventListener extends StatefulObserverWidget {
  final Widget? child;

  const ArrangerEventListener({
    Key? key,
    this.child,
  }) : super(key: key);

  @override
  State<ArrangerEventListener> createState() => _ArrangerEventListenerState();
}

class _ArrangerEventListenerState extends State<ArrangerEventListener> {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);

    return EditorScrollManager(
      timeView: viewModel.timeView,
      onVerticalScrollChange: (pixelDelta) {
        viewModel.verticalScrollPosition = (viewModel.verticalScrollPosition +
                pixelDelta * 0.01 * viewModel.baseTrackHeight)
            .clamp(0, double.infinity);
      },
      child: Listener(child: widget.child),
    );
  }
}
