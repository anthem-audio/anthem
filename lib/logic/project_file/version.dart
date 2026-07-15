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

/// A software version stored in an Anthem project file.
///
/// Versions have three numeric components and an optional suffix, such as
/// `0.0.0-prealpha.2`.
final class ProjectFileVersion implements Comparable<ProjectFileVersion> {
  const ProjectFileVersion({
    required this.major,
    required this.minor,
    required this.bugfix,
    this.extra,
  });

  factory ProjectFileVersion.parse(String version) {
    final match = _versionPattern.firstMatch(version);

    if (match == null) {
      throw FormatException('Invalid Anthem project file version: $version');
    }

    return ProjectFileVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      bugfix: int.parse(match.group(3)!),
      extra: match.group(4),
    );
  }

  static final _versionPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$');
  static final _extraPartPattern = RegExp(r'\d+|\D+');

  final int major;
  final int minor;
  final int bugfix;
  final String? extra;

  @override
  int compareTo(ProjectFileVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) return majorComparison;

    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) return minorComparison;

    final bugfixComparison = bugfix.compareTo(other.bugfix);
    if (bugfixComparison != 0) return bugfixComparison;

    return _compareExtra(extra, other.extra);
  }

  bool operator <(ProjectFileVersion other) => compareTo(other) < 0;

  bool operator <=(ProjectFileVersion other) => compareTo(other) <= 0;

  bool operator >(ProjectFileVersion other) => compareTo(other) > 0;

  bool operator >=(ProjectFileVersion other) => compareTo(other) >= 0;

  static int _compareExtra(String? left, String? right) {
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;

    final leftParts = _extraPartPattern
        .allMatches(left)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final rightParts = _extraPartPattern
        .allMatches(right)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final sharedLength = leftParts.length < rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var i = 0; i < sharedLength; i++) {
      final leftPart = leftParts[i];
      final rightPart = rightParts[i];
      final leftNumber = BigInt.tryParse(leftPart);
      final rightNumber = BigInt.tryParse(rightPart);

      final partComparison = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftPart.compareTo(rightPart);
      if (partComparison != 0) return partComparison;
    }

    final lengthComparison = leftParts.length.compareTo(rightParts.length);
    if (lengthComparison != 0) return lengthComparison;

    // Preserve a total ordering for numerically equivalent text such as
    // `prealpha.1` and `prealpha.01`.
    return left.compareTo(right);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectFileVersion &&
        major == other.major &&
        minor == other.minor &&
        bugfix == other.bugfix &&
        extra == other.extra;
  }

  @override
  int get hashCode => Object.hash(major, minor, bugfix, extra);

  @override
  String toString() {
    final suffix = extra == null ? '' : '-$extra';
    return '$major.$minor.$bugfix$suffix';
  }
}

const String currentProjectFileSoftwareVersion = '0.0.0-prealpha.2';

final ProjectFileVersion currentProjectFileVersion = ProjectFileVersion.parse(
  currentProjectFileSoftwareVersion,
);

/// The oldest version that has enough version information to migrate safely.
const ProjectFileVersion oldestSupportedProjectFileVersion = ProjectFileVersion(
  major: 0,
  minor: 0,
  bugfix: 0,
  extra: 'prealpha.1',
);

/// Compares two project-file version strings for use with [List.sort].
int compareProjectFileVersionStrings(String left, String right) {
  return ProjectFileVersion.parse(
    left,
  ).compareTo(ProjectFileVersion.parse(right));
}
