/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'controller/arranger_controller.dart';
import 'scroll_manager.dart';
import 'view_model.dart';

class ArrangerEventListener extends StatefulWidget {
  final Widget? child;

  const ArrangerEventListener({super.key, this.child});

  @override
  State<ArrangerEventListener> createState() => _ArrangerEventListenerState();
}

class _ArrangerEventListenerState extends State<ArrangerEventListener> {
  Size? _lastViewSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, boxConstraints) {
        final viewSize = boxConstraints.biggest;
        final controller = Provider.of<ArrangerController>(
          context,
          listen: false,
        );

        if (_lastViewSize != viewSize) {
          _lastViewSize = viewSize;
          controller.onViewSizeChanged(viewSize);
        }

        return ArrangerScrollManager.editor(
          child: Observer(
            builder: (context) {
              final viewModel = Provider.of<ArrangerViewModel>(context);

              return MouseRegion(
                cursor: viewModel.mouseCursor,
                onEnter: controller.onEnter,
                onExit: controller.onExit,
                onHover: controller.onHover,
                child: Listener(
                  onPointerDown: (event) {
                    controller.pointerDown(event);
                  },
                  onPointerMove: (event) {
                    controller.pointerMove(event);
                  },
                  onPointerUp: (event) {
                    controller.pointerUp(event);
                  },
                  onPointerCancel: (event) {
                    controller.pointerUp(event);
                  },
                  child: widget.child,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
