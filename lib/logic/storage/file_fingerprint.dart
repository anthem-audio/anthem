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

import 'package:anthem_codegen/include.dart';
import 'package:crypto/crypto.dart' as crypto;

part 'file_fingerprint.g.dart';

/// Byte length and SHA-256 digest of a file's complete contents.
@AnthemModel(serializable: true, generateCpp: true)
class FileFingerprint extends _FileFingerprint
    with _$FileFingerprintAnthemModelMixin {
  FileFingerprint({required super.byteLength, required super.sha256});

  FileFingerprint.uninitialized() : super(byteLength: 0, sha256: '');

  factory FileFingerprint.fromBytes(List<int> bytes) => FileFingerprint(
    byteLength: bytes.length,
    sha256: crypto.sha256.convert(bytes).toString(),
  );

  factory FileFingerprint.fromJson(Map<String, dynamic> json) =>
      _$FileFingerprintAnthemModelMixin.fromJson(json);
}

abstract class _FileFingerprint {
  int byteLength;
  String sha256;

  _FileFingerprint({required this.byteLength, required this.sha256});
}
