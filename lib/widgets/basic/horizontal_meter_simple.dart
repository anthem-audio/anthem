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
import 'package:flutter/widgets.dart';

class HorizontalMeterSimple extends StatelessWidget {
  final double width;
  final double value;
  final String label;

  const HorizontalMeterSimple({
    super.key,
    required this.width,
    this.label = '',
    this.value = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.control.background,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Theme.control.border,
                  width: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: 1,
            bottom: 1,
            top: 1,
            right: 1,
            child: ClipRect(
              clipper: _RectangularProgressClipper(value: value),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.primary.subtleBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.text.main, // Should be an accent color when we restyle everything
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RectangularProgressClipper extends CustomClipper<Rect> {
  final double value;

  const _RectangularProgressClipper({required this.value});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * value, size.height);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    return oldClipper is _RectangularProgressClipper &&
        oldClipper.value != value;
  }
}
