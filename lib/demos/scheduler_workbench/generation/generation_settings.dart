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

import 'package:mobx/mobx.dart';

part 'generation_settings.g.dart';

class GenerationSettings {
  final int trackCount;
  final int sendCount;
  final int busTrackCount;
  final int busTrackInputCount;
  final int minNodeSteps;
  final int maxNodeSteps;
  final int minNodeProcessingTicks;
  final int maxNodeProcessingTicks;
  final int crossTrackConnectionCount;
  final double splitChance;
  final double recombineChance;
  final int seed;

  const GenerationSettings({
    required this.trackCount,
    required this.sendCount,
    required this.busTrackCount,
    required this.busTrackInputCount,
    required this.minNodeSteps,
    required this.maxNodeSteps,
    required this.minNodeProcessingTicks,
    required this.maxNodeProcessingTicks,
    required this.crossTrackConnectionCount,
    required this.splitChance,
    required this.recombineChance,
    required this.seed,
  });
}

// ignore: library_private_types_in_public_api
class GenerationSettingsViewModel = _GenerationSettingsViewModel
    with _$GenerationSettingsViewModel;

abstract class _GenerationSettingsViewModel with Store {
  @observable
  int trackCount = 100;

  @observable
  int sendCount = 5;

  @observable
  int busTrackCount = 3;

  @observable
  int busTrackInputCount = 5;

  @observable
  int minNodeSteps = 3;

  @observable
  int maxNodeSteps = 20;

  @observable
  int minNodeProcessingTicks = 1;

  @observable
  int maxNodeProcessingTicks = 12;

  @observable
  int crossTrackConnectionCount = 15;

  @observable
  double splitChance = 0.1;

  @observable
  double recombineChance = 0.45;

  @observable
  int seed = 1823;

  GenerationSettings toSettings() {
    return GenerationSettings(
      trackCount: trackCount,
      sendCount: sendCount,
      busTrackCount: busTrackCount,
      busTrackInputCount: busTrackInputCount,
      minNodeSteps: minNodeSteps,
      maxNodeSteps: maxNodeSteps,
      minNodeProcessingTicks: minNodeProcessingTicks,
      maxNodeProcessingTicks: maxNodeProcessingTicks,
      crossTrackConnectionCount: crossTrackConnectionCount,
      splitChance: splitChance,
      recombineChance: recombineChance,
      seed: seed,
    );
  }

  @action
  void setTrackCount(int value) {
    trackCount = value.clamp(1, 512);
  }

  @action
  void setSendCount(int value) {
    sendCount = value.clamp(0, 16);
  }

  @action
  void setBusTrackCount(int value) {
    busTrackCount = value.clamp(0, 64);
  }

  @action
  void setBusTrackInputCount(int value) {
    busTrackInputCount = value.clamp(0, 512);
  }

  @action
  void setMinNodeSteps(int value) {
    minNodeSteps = value.clamp(1, maxNodeSteps);
  }

  @action
  void setMaxNodeSteps(int value) {
    maxNodeSteps = value.clamp(minNodeSteps, 64);
  }

  @action
  void setMinNodeProcessingTicks(int value) {
    minNodeProcessingTicks = value.clamp(1, maxNodeProcessingTicks);
  }

  @action
  void setMaxNodeProcessingTicks(int value) {
    maxNodeProcessingTicks = value.clamp(minNodeProcessingTicks, 1000000);
  }

  @action
  void setCrossTrackConnectionCount(int value) {
    crossTrackConnectionCount = value.clamp(0, 10000);
  }

  @action
  void setSplitChance(double value) {
    splitChance = value.clamp(0.0, 1.0);
  }

  @action
  void setRecombineChance(double value) {
    recombineChance = value.clamp(0.0, 1.0);
  }

  @action
  void setSeed(int value) {
    seed = value.clamp(0, 0x7FFFFFFF);
  }

  @action
  void randomizeSeed() {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
  }
}
