/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:async';

import 'package:anthem/logic/render/project_render_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/horizontal_meter_simple.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

final _log = Logger('render_progress_dialog');

class RenderProgressDialog extends StatefulWidget {
  final ProjectRenderTask task;

  const RenderProgressDialog({super.key, required this.task});

  @override
  State<RenderProgressDialog> createState() => _RenderProgressDialogState();
}

class _RenderProgressDialogState extends State<RenderProgressDialog> {
  StreamSubscription<ProjectRenderProgress>? _progressSubscription;
  double _progress = 0;
  String _statusText = 'Preparing render...';

  @override
  void initState() {
    super.initState();

    _progressSubscription = widget.task.progressStream.listen((progress) {
      if (!mounted) {
        return;
      }

      setState(() {
        _progress = progress.progress;
        _statusText = progress.statusText;
      });
    });

    unawaited(_watchResult());
  }

  @override
  void dispose() {
    unawaited(_progressSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          SizedBox(
            height: 24,
            child: HorizontalMeterSimple(
              width: 500,
              value: _progress,
              label: _progressLabel,
            ),
          ),
          Text(
            _statusText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _watchResult() async {
    try {
      await widget.task.result;

      if (!mounted) {
        return;
      }

      setState(() {
        _progress = 1;
        _statusText = 'Render complete.';
      });

      ServiceRegistry.dialogController.closeDialog();
    } catch (error, stackTrace) {
      _log.warning('Could not render project.', error, stackTrace);

      if (!mounted) {
        return;
      }

      _showRenderFailedDialog('Render failed: $error');
    }
  }

  void _showRenderFailedDialog(String message) {
    final dialogController = ServiceRegistry.dialogController;
    dialogController.closeDialog();
    dialogController.showDialog(
      title: 'Render Failed',
      content: SizedBox(
        width: 500,
        child: Text(
          message,
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
      ),
      buttons: [DialogButton.ok()],
    );
  }

  String get _progressLabel {
    if (_progress <= 0) {
      return '';
    }

    return '${(_progress * 100).round()}%';
  }
}
