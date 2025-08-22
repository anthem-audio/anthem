/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

/// A helper class that helps in creating smooth animations.
///
/// This class tracks one or more values, and produces animations for those
/// values that smooth out transitions when the values are updated.
class LazyFollowAnimationHelper {
  // Fields for time view animation

  late final AnimationController animationController;

  final double duration;
  final List<LazyFollowItem> items;

  LazyFollowAnimationHelper({
    required this.duration,
    required this.items,
    required TickerProvider vsync,
  }) {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: vsync,
    );

    for (final item in items) {
      item._init(animationController);
    }
  }

  /// Should be called on build before widgets are returned. This updates the
  /// animation in case any values have changed.
  void update() {
    // Updates the animation if the value has changed
    final itemsToUpdate = items.map((item) {
      final target = item.getTarget?.call() ?? item.target;
      return (item: item, target: target);
    }).toList();

    for (final (:item, target: _) in itemsToUpdate) {
      item.tween.begin = item.animation.value;
    }

    animationController.reset();

    for (final (:item, :target) in itemsToUpdate) {
      item.tween.end = target;
    }

    animationController.forward();

    for (final (:item, :target) in itemsToUpdate) {
      item.mostRecentValue = target;
    }
  }

  void dispose() {
    animationController.dispose();
  }
}

class LazyFollowItem {
  final double Function()? getTarget;

  double mostRecentValue;
  double target;

  late final Tween<double> tween;

  late final Animation<double> animation;

  late final AnimationController animationController;

  void _init(AnimationController controller) {
    animationController = controller;
    tween = Tween<double>(begin: mostRecentValue, end: mostRecentValue);
    animation = tween.animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutExpo),
    );
  }

  LazyFollowItem({required double initialValue, this.getTarget})
    : mostRecentValue = initialValue,
      target = initialValue;

  void snapTo(double value) {
    tween.begin = value;
    animationController.reset();
    tween.end = value;
    animationController.forward();
    mostRecentValue = value;
  }

  void setTarget(double value) {
    target = value;
  }
}
