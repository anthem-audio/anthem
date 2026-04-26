/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../generation/generation_settings.dart';

class GenerationPanel extends StatelessWidget {
  final GenerationSettingsViewModel settings;
  final VoidCallback onRegenerate;

  const GenerationPanel({
    super.key,
    required this.settings,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF171717),
        border: Border(right: BorderSide(color: Color(0xFF303030))),
      ),
      child: SizedBox(
        width: 310,
        child: Observer(
          builder: (context) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Generation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _IntegerSetting(
                  label: 'Tracks',
                  value: settings.trackCount,
                  onChanged: settings.setTrackCount,
                ),
                _IntegerSetting(
                  label: 'Sends',
                  value: settings.sendCount,
                  onChanged: settings.setSendCount,
                ),
                _IntegerSetting(
                  label: 'Bus tracks',
                  value: settings.busTrackCount,
                  onChanged: settings.setBusTrackCount,
                ),
                _IntegerSetting(
                  label: 'Tracks per bus',
                  value: settings.busTrackInputCount,
                  onChanged: settings.setBusTrackInputCount,
                ),
                _IntegerSetting(
                  label: 'Min node steps',
                  value: settings.minNodeSteps,
                  onChanged: settings.setMinNodeSteps,
                ),
                _IntegerSetting(
                  label: 'Max node steps',
                  value: settings.maxNodeSteps,
                  onChanged: settings.setMaxNodeSteps,
                ),
                _IntegerSetting(
                  label: 'Min processing ticks',
                  value: settings.minNodeProcessingTicks,
                  onChanged: settings.setMinNodeProcessingTicks,
                ),
                _IntegerSetting(
                  label: 'Max processing ticks',
                  value: settings.maxNodeProcessingTicks,
                  onChanged: settings.setMaxNodeProcessingTicks,
                ),
                _IntegerSetting(
                  label: 'Cross-track connections',
                  value: settings.crossTrackConnectionCount,
                  onChanged: settings.setCrossTrackConnectionCount,
                ),
                const SizedBox(height: 12),
                Text(
                  'Split chance: ${settings.splitChance.toStringAsFixed(2)}',
                ),
                Slider(
                  value: settings.splitChance,
                  onChanged: settings.setSplitChance,
                ),
                const SizedBox(height: 12),
                Text(
                  'Recombine chance: '
                  '${settings.recombineChance.toStringAsFixed(2)}',
                ),
                Slider(
                  value: settings.recombineChance,
                  onChanged: settings.setRecombineChance,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('Seed: ${settings.seed}')),
                    IconButton(
                      tooltip: 'Randomize seed',
                      onPressed: settings.randomizeSeed,
                      icon: const Icon(Icons.casino_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IntegerSetting extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _IntegerSetting({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_IntegerSetting> createState() => _IntegerSettingState();
}

class _IntegerSettingState extends State<_IntegerSetting> {
  late final FocusNode focusNode;
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value.toString());
    focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _IntegerSetting oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!focusNode.hasFocus && oldWidget.value != widget.value) {
      controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!focusNode.hasFocus) {
      _submit(controller.text);
    }
  }

  void _submit(String value) {
    final parsed = int.tryParse(value);

    if (parsed != null) {
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(widget.label)),
          SizedBox(
            width: 86,
            child: TextFormField(
              focusNode: focusNode,
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (value) {
                _submit(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
