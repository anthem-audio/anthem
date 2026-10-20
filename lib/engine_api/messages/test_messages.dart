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

part of 'messages.dart';

/// Requests a [TestUiEchoResponse] containing [value].
///
/// Used by integration tests to verify engine-to-UI requests.
class TestUiEchoRequest extends Request {
  late String value;

  TestUiEchoRequest.uninitialized();

  TestUiEchoRequest({required int id, required this.value}) {
    super.id = id;
  }
}

class TestUiEchoResponse extends Response {
  late String value;

  TestUiEchoResponse.uninitialized();

  TestUiEchoResponse({required int id, required this.value}) {
    super.id = id;
  }
}

/// Requests an engine-to-UI echo round trip for integration tests.
///
/// The engine sends a [TestUiEchoRequest] and returns a
/// [TestUiEchoRoundTripResponse] when that request completes or fails. This tests
/// UI request handling while a UI-to-engine request is pending.
class TestUiEchoRoundTripRequest extends Request {
  late String value;
  late int timeoutMilliseconds;

  TestUiEchoRoundTripRequest.uninitialized();

  TestUiEchoRoundTripRequest({
    required int id,
    required this.value,
    this.timeoutMilliseconds = 5000,
  }) {
    super.id = id;
  }
}

class TestUiEchoRoundTripResponse extends Response {
  String? value;
  String? error;

  TestUiEchoRoundTripResponse.uninitialized();

  TestUiEchoRoundTripResponse({required int id, this.value, this.error}) {
    super.id = id;
  }
}

/// Selects one storage-client operation for real-engine integration tests.
@AnthemEnum()
enum TestFileStorageOperation {
  beginWrite,
  commitWrite,
  abortWrite,
  acquireRead,
  releaseRead,
  deleteFile,
  retainFile,
  releaseRetention,
}

/// Runs a storage operation through the C++ client.
///
/// The beginWrite operation writes [data], and acquireRead reads it back.
/// Each operation closes its OS file before replying, but keeps the token active
/// until a later command releases it or the engine shuts down.
class TestFileStorageRequest extends Request {
  late TestFileStorageOperation operation;
  String category = 'plugin states';
  String? baseName;
  String? extension;
  String data = '';
  String token = '';
  String relativePath = '';

  TestFileStorageRequest.uninitialized();
  TestFileStorageRequest({
    required int id,
    required this.operation,
    this.category = 'plugin states',
    this.baseName,
    this.extension,
    this.data = '',
    this.token = '',
    this.relativePath = '',
  }) {
    super.id = id;
  }
}

class TestFileStorageResponse extends Response {
  String? token;
  String? absolutePath;
  String? relativePath;
  String? data;
  String? error;

  TestFileStorageResponse.uninitialized();
  TestFileStorageResponse({
    required int id,
    this.token,
    this.absolutePath,
    this.relativePath,
    this.data,
    this.error,
  }) {
    super.id = id;
  }
}
