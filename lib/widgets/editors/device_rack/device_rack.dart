/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

import 'dart:math' as math;

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/hint/hint.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/editors/device_rack/devices/device_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

const _scrollbarShortSideLength = 17.0;
const _deviceRackVerticalPadding = 8.0;
const _deviceRackItemHeight = 207.0;
const _deviceRackPanelBorderHeight = 10.0;

class DeviceRack extends StatefulObserverWidget {
  static const fixedPanelHeight =
      _deviceRackItemHeight +
      _deviceRackVerticalPadding * 2 +
      _scrollbarShortSideLength +
      _deviceRackPanelBorderHeight;

  const DeviceRack({super.key});

  @override
  State<DeviceRack> createState() => _DeviceRackState();
}

class _DeviceRackState extends State<DeviceRack> {
  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final arrangerViewModel = serviceRegistry.arrangerViewModel;

    final activeTrackId = arrangerViewModel.selectedTracks.firstOrNull;

    if (activeTrackId == null) {
      return Container(
        color: AnthemTheme.panel.background,
        child: Center(
          child: Text(
            'No track selected',
            style: TextStyle(color: AnthemTheme.text.main),
          ),
        ),
      );
    }

    return Container(
      color: AnthemTheme.panel.border,
      child: _buildRack(context, project, activeTrackId),
    );
  }
}

Widget _buildRack(
  BuildContext context,
  ProjectModel project,
  Id activeTrackId,
) {
  final track = project.tracks[activeTrackId];

  if (track == null) {
    return const Text('Invalid track');
  }

  return _DeviceRackScrollArea(track: track);
}

class _DeviceRackScrollArea extends StatefulObserverWidget {
  final TrackModel track;

  const _DeviceRackScrollArea({required this.track});

  @override
  State<_DeviceRackScrollArea> createState() => _DeviceRackScrollAreaState();
}

class _DeviceRackScrollAreaState extends State<_DeviceRackScrollArea> {
  late final ScrollController _scrollController;

  double _viewportWidth = 0;
  double _maxScrollExtent = 0;
  bool _metricsSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _DeviceRackScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.track.id != widget.track.id && _scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMetricsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              _updateMetrics(notification.metrics);
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: .symmetric(vertical: _deviceRackVerticalPadding),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: _deviceRackItemHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildRackChildren(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _DeviceRackHorizontalScrollbar(
          scrollController: _scrollController,
          viewportWidth: _viewportWidth,
          maxScrollExtent: _maxScrollExtent,
        ),
      ],
    );
  }

  List<Widget> _buildRackChildren() {
    if (widget.track.devices.isEmpty) {
      return [_AddButton(trackId: widget.track.id, index: 0)];
    }

    return [
      _AddButton(trackId: widget.track.id, index: 0),
      for (final (index, device) in widget.track.devices.indexed) ...[
        DeviceView(
          key: ValueKey(device.id),
          trackId: widget.track.id,
          device: device,
        ),
        _AddButton(trackId: widget.track.id, index: index + 1),
      ],
      const SizedBox(width: 8),
    ];
  }

  void _scheduleMetricsSync() {
    if (_metricsSyncScheduled) return;

    _metricsSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsSyncScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;

      final position = _scrollController.position;
      _updateMetrics(position);

      final maxScrollExtent = math.max(0.0, position.maxScrollExtent);
      final clampedOffset = position.pixels
          .clamp(position.minScrollExtent, maxScrollExtent)
          .toDouble();

      if (clampedOffset != position.pixels) {
        _scrollController.jumpTo(clampedOffset);
      }
    });
  }

  void _updateMetrics(ScrollMetrics metrics) {
    if (axisDirectionToAxis(metrics.axisDirection) != Axis.horizontal) {
      return;
    }

    final nextViewportWidth = metrics.viewportDimension.isFinite
        ? math.max(0.0, metrics.viewportDimension)
        : 0.0;
    final nextMaxScrollExtent = metrics.maxScrollExtent.isFinite
        ? math.max(0.0, metrics.maxScrollExtent)
        : 0.0;

    if (nextViewportWidth == _viewportWidth &&
        nextMaxScrollExtent == _maxScrollExtent) {
      return;
    }

    setState(() {
      _viewportWidth = nextViewportWidth;
      _maxScrollExtent = nextMaxScrollExtent;
    });
  }
}

class _DeviceRackHorizontalScrollbar extends StatelessWidget {
  final ScrollController scrollController;
  final double viewportWidth;
  final double maxScrollExtent;

  const _DeviceRackHorizontalScrollbar({
    required this.scrollController,
    required this.viewportWidth,
    required this.maxScrollExtent,
  });

  @override
  Widget build(BuildContext context) {
    final scrollRegionEnd = viewportWidth + maxScrollExtent;

    return Container(
      height: _scrollbarShortSideLength,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AnthemTheme.panel.border)),
        color: AnthemTheme.panel.background,
      ),
      child: AnimatedBuilder(
        animation: scrollController,
        builder: (context, child) {
          final scrollOffset = scrollController.hasClients
              ? scrollController.offset.clamp(0.0, maxScrollExtent).toDouble()
              : 0.0;

          return ScrollbarRenderer(
            scrollRegionStart: 0,
            scrollRegionEnd: scrollRegionEnd,
            handleStart: scrollOffset,
            handleEnd: scrollOffset + viewportWidth,
            onChange: (event) {
              if (!scrollController.hasClients) {
                return;
              }

              scrollController.jumpTo(
                event.handleStart.clamp(0.0, maxScrollExtent).toDouble(),
              );
            },
          );
        },
      ),
    );
  }
}

MenuDef _buildAddDeviceMenuDef(BuildContext context, Id trackId, int index) {
  final project = Provider.of<ProjectModel>(context, listen: false);
  final serviceRegistry = ServiceRegistry.forProject(project.id);
  final deviceController = serviceRegistry.deviceController;

  return MenuDef(
    children: [
      AnthemMenuItem(
        text: 'Tone Generator',
        onSelected: () {
          deviceController.addDevice(
            trackId: trackId,
            type: DeviceType.toneGenerator,
            index: index,
          );
        },
      ),
      AnthemMenuItem(
        text: 'Utility',
        onSelected: () {
          deviceController.addDevice(
            trackId: trackId,
            type: DeviceType.utility,
            index: index,
          );
        },
      ),
      if (!kIsWeb) Separator(),
      if (!kIsWeb)
        AnthemMenuItem(
          text: 'VST3...',
          onSelected: () {
            deviceController.addDevice(
              trackId: trackId,
              type: DeviceType.vst3Plugin,
              index: index,
            );
          },
        ),
    ],
  );
}

class _AddButton extends StatefulWidget {
  final Id trackId;
  final int index;

  const _AddButton({required this.trackId, required this.index});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  final AnthemMenuController _menuController = AnthemMenuController();

  bool _isHovered = false;
  bool _isPressed = false;
  bool _hoverLock = false;

  @override
  Widget build(BuildContext context) {
    final backgroundBaseColor = AnthemTheme.panel.border;
    final backgroundColor = _isPressed
        ? _adjustGreyLightness(backgroundBaseColor, 0.015)
        : _isHovered || _hoverLock
        ? _adjustGreyLightness(backgroundBaseColor, 0.03)
        : backgroundBaseColor;

    return Menu(
      menuController: _menuController,
      menuDef: _buildAddDeviceMenuDef(context, widget.trackId, widget.index),
      onClose: () {
        setState(() {
          _hoverLock = false;
        });
      },
      child: Hint(
        hint: [.new('click', 'Add a device to this track')],
        child: MouseRegion(
          onEnter: (e) {
            setState(() {
              _isHovered = true;
            });
          },
          onExit: (e) {
            setState(() {
              _isHovered = false;
              _isPressed = false;
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              setState(() {
                _isPressed = false;
                _hoverLock = true;
              });
              _menuController.open(details.globalPosition);
            },
            onTapCancel: () {
              setState(() {
                _isPressed = false;
              });
            },
            child: Listener(
              onPointerDown: (event) {
                setState(() {
                  _isPressed = true;
                });
              },
              onPointerUp: (event) {
                setState(() {
                  _isPressed = false;
                });
              },
              onPointerCancel: (event) {
                setState(() {
                  _isPressed = false;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  width: 15,
                  child: Center(
                    child: SvgIcon(
                      icon: Icons.add,
                      color: _isHovered
                          ? AnthemTheme.text.accent
                          : AnthemTheme.text.main,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _adjustGreyLightness(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);

  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0).toDouble())
      .toColor();
}
