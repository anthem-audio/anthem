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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:logging/logging.dart';

const _maxSessionCount = 10;
const _maxSessionAge = Duration(days: 14);
const _maxTotalLogBytes = 100 * 1024 * 1024;

class AnthemLogManager {
  static const engineLogSessionEnvironmentKey = 'ANTHEM_LOG_SESSION_DIR';

  static final AnthemLogManager instance = AnthemLogManager._();

  AnthemLogManager._();

  final _managerLogger = Logger('logging');

  bool _initialized = false;
  int _recordSequence = 0;

  late Directory _logRoot;
  late Directory _sessionsRoot;
  Directory? _activeSessionDirectory;
  StreamSubscription<LogRecord>? _recordSubscription;
  IOSink? _appLogSink;

  String? get activeSessionDirectoryPath => _activeSessionDirectory?.path;

  Map<String, String> get childProcessEnvironment {
    final activeSessionDirectoryPath = this.activeSessionDirectoryPath;
    if (activeSessionDirectoryPath == null) {
      return const {};
    }

    return {engineLogSessionEnvironmentKey: activeSessionDirectoryPath};
  }

  Future<void> initialize({Directory? rootDirectory}) async {
    if (_initialized) {
      return;
    }

    _logRoot = rootDirectory ?? _defaultLogRoot();
    _sessionsRoot = Directory(_joinPath([_logRoot.path, 'sessions']));
    _activeSessionDirectory = Directory(
      _joinPath([_sessionsRoot.path, _createSessionDirectoryName()]),
    );

    await _activeSessionDirectory!.create(recursive: true);
    await _writeSessionMetadata();

    final appLogFile = File(
      _joinPath([_activeSessionDirectory!.path, 'app.log']),
    );
    _appLogSink = appLogFile.openWrite(mode: FileMode.append);

    Logger.root.clearListeners();
    Logger.root.level = Level.ALL;
    recordStackTraceAtLevel = Level.SEVERE;
    _recordSubscription = Logger.root.onRecord.listen(_writeRecord);

    _initialized = true;

    _managerLogger.info(
      'Logging initialized at ${_activeSessionDirectory!.path}',
    );

    _schedulePruneOldSessions();
  }

  Future<void> flush() async {
    await _appLogSink?.flush();
  }

  Future<void> dispose() async {
    await _recordSubscription?.cancel();
    await _appLogSink?.flush();
    await _appLogSink?.close();
    _recordSubscription = null;
    _appLogSink = null;
    _initialized = false;
  }

  Future<String> exportLogs({required String outputPath}) async {
    _assertInitialized();
    await flush();

    var zipPath = outputPath;
    if (!zipPath.toLowerCase().endsWith('.zip')) {
      zipPath = '$zipPath.zip';
    }

    if (_isWithinLogRoot(zipPath)) {
      throw ArgumentError('Log export path must be outside the log folder.');
    }

    final outputFile = File(zipPath);
    await outputFile.parent.create(recursive: true);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final files = <File>[];
    await for (final entity in _logRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        files.add(entity);
      }
    }

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    try {
      for (final file in files) {
        final entryName = 'AnthemLogs/${_relativeToLogRoot(file.path)}';
        await encoder.addFile(file, entryName);
      }
    } finally {
      await encoder.close();
    }

    _managerLogger.info('Exported logs to $zipPath');
    return zipPath;
  }

  void _assertInitialized() {
    if (!_initialized) {
      throw StateError('Anthem logging has not been initialized.');
    }
  }

  Directory _defaultLogRoot() {
    final environment = Platform.environment;

    if (Platform.isMacOS) {
      final home = environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(_joinPath([home, 'Library', 'Logs', 'Anthem']));
      }
    }

    if (Platform.isWindows) {
      final localAppData =
          environment['LOCALAPPDATA'] ?? environment['APPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return Directory(_joinPath([localAppData, 'Anthem', 'Logs']));
      }
    }

    if (Platform.isLinux) {
      final xdgStateHome = environment['XDG_STATE_HOME'];
      if (xdgStateHome != null && xdgStateHome.isNotEmpty) {
        return Directory(_joinPath([xdgStateHome, 'anthem', 'logs']));
      }

      final home = environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(
          _joinPath([home, '.local', 'state', 'anthem', 'logs']),
        );
      }
    }

    return Directory(_joinPath([Directory.systemTemp.path, 'anthem', 'logs']));
  }

  String _createSessionDirectoryName() {
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    return '$timestamp-$pid';
  }

  Future<void> _writeSessionMetadata() async {
    final metadata = {
      'schemaVersion': 1,
      'sessionId': _basename(_activeSessionDirectory!.path),
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'processId': pid,
      'executable': Platform.resolvedExecutable,
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
      'locale': Platform.localeName,
      'logRoot': _logRoot.path,
      'retention': {
        'maxSessionCount': _maxSessionCount,
        'maxSessionAgeDays': _maxSessionAge.inDays,
        'maxTotalBytes': _maxTotalLogBytes,
      },
    };

    final file = File(
      _joinPath([_activeSessionDirectory!.path, 'metadata.json']),
    );
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(metadata)}\n',
      flush: true,
    );
  }

  void _writeRecord(LogRecord record) {
    final sink = _appLogSink;
    if (sink == null) {
      return;
    }

    final buffer = StringBuffer()
      ..write(record.time.toUtc().toIso8601String())
      ..write(' ')
      ..write(record.level.name.padRight(7))
      ..write(' #')
      ..write(_recordSequence++)
      ..write(' [')
      ..write(record.loggerName)
      ..writeln(']');

    _writeIndentedBlock(buffer, record.message);

    if (record.error != null) {
      _writeIndentedBlock(buffer, 'Error: ${record.error}');
    }

    if (record.stackTrace != null) {
      buffer.writeln('  Stack trace:');
      _writeIndentedBlock(buffer, record.stackTrace.toString(), indent: '    ');
    }

    sink.write(buffer.toString());
  }

  void _schedulePruneOldSessions() {
    unawaited(
      _pruneOldSessions().catchError((Object error, StackTrace stackTrace) {
        _managerLogger.warning(
          'Could not prune old log sessions.',
          error,
          stackTrace,
        );
      }),
    );
  }

  void _writeIndentedBlock(
    StringBuffer buffer,
    String text, {
    String indent = '  ',
  }) {
    final normalizedText = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trimRight();

    if (normalizedText.isEmpty) {
      buffer.writeln(indent);
      return;
    }

    for (final line in normalizedText.split('\n')) {
      buffer
        ..write(indent)
        ..writeln(line);
    }
  }

  Future<void> _pruneOldSessions() async {
    final activePath = _activeSessionDirectory!.absolute.path;

    var sessionDirectories = await _listSessionDirectories();
    final now = DateTime.now();

    for (final directory in sessionDirectories) {
      if (directory.absolute.path == activePath) {
        continue;
      }

      final stat = await directory.stat();
      if (now.difference(stat.modified) > _maxSessionAge) {
        await _deleteDirectoryQuietly(directory);
      }
    }

    sessionDirectories = await _listSessionDirectories();
    sessionDirectories.sort((a, b) {
      return b.statSync().modified.compareTo(a.statSync().modified);
    });

    var retainedInactiveSessions = 0;
    for (final directory in sessionDirectories) {
      if (directory.absolute.path == activePath) {
        continue;
      }

      retainedInactiveSessions++;
      if (retainedInactiveSessions > _maxSessionCount - 1) {
        await _deleteDirectoryQuietly(directory);
      }
    }

    await _pruneToTotalSize(activePath);
  }

  Future<void> _pruneToTotalSize(String activePath) async {
    var sessionDirectories = await _listSessionDirectories();
    var totalSize = await _totalDirectorySize(_sessionsRoot);

    while (totalSize > _maxTotalLogBytes) {
      final inactiveSessionDirectories =
          sessionDirectories
              .where((directory) => directory.absolute.path != activePath)
              .toList(growable: false)
            ..sort((a, b) {
              return a.statSync().modified.compareTo(b.statSync().modified);
            });

      if (inactiveSessionDirectories.isEmpty) {
        return;
      }

      final directory = inactiveSessionDirectories.first;
      final deletedSize = await _totalDirectorySize(directory);
      await _deleteDirectoryQuietly(directory);

      totalSize -= deletedSize;
      sessionDirectories = await _listSessionDirectories();
    }
  }

  Future<List<Directory>> _listSessionDirectories() async {
    if (!await _sessionsRoot.exists()) {
      return const [];
    }

    final directories = <Directory>[];
    await for (final entity in _sessionsRoot.list(followLinks: false)) {
      if (entity is Directory) {
        directories.add(entity);
      }
    }

    return directories;
  }

  Future<int> _totalDirectorySize(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }

    var size = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        size += await entity.length();
      }
    }

    return size;
  }

  Future<void> _deleteDirectoryQuietly(Directory directory) async {
    try {
      await directory.delete(recursive: true);
    } catch (error, stackTrace) {
      _managerLogger.warning(
        'Could not delete old log session ${directory.path}',
        error,
        stackTrace,
      );
    }
  }

  bool _isWithinLogRoot(String path) {
    var rootPath = _withTrailingSeparator(_logRoot.absolute.path);
    var candidatePath = File(path).absolute.path;

    if (Platform.isWindows) {
      rootPath = rootPath.toLowerCase();
      candidatePath = candidatePath.toLowerCase();
    }

    return candidatePath.startsWith(rootPath);
  }

  String _relativeToLogRoot(String path) {
    final rootPath = _withTrailingSeparator(_logRoot.absolute.path);
    final candidatePath = File(path).absolute.path;

    return candidatePath
        .substring(rootPath.length)
        .split(Platform.pathSeparator)
        .join('/');
  }

  String _withTrailingSeparator(String path) {
    if (path.endsWith(Platform.pathSeparator)) {
      return path;
    }

    return '$path${Platform.pathSeparator}';
  }

  String _basename(String path) {
    final normalizedPath = _stripTrailingSeparators(path);
    final separatorIndex = normalizedPath.lastIndexOf(Platform.pathSeparator);

    if (separatorIndex == -1) {
      return normalizedPath;
    }

    return normalizedPath.substring(separatorIndex + 1);
  }

  String _joinPath(List<String> parts) {
    return parts
        .where((part) => part.isNotEmpty)
        .map(_stripTrailingSeparators)
        .join(Platform.pathSeparator);
  }

  String _stripTrailingSeparators(String path) {
    var result = path;
    while (result.length > 1 &&
        (result.endsWith('/') || result.endsWith(r'\'))) {
      result = result.substring(0, result.length - 1);
    }

    return result;
  }
}
