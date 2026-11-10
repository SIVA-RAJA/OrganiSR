import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';

class RestoreResult {
  final bool success;
  final int restoredPages;
  final int preservedPages;
  final String? errorMessage;

  const RestoreResult({
    required this.success,
    this.restoredPages = 0,
    this.preservedPages = 0,
    this.errorMessage,
  });
}

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  static const String _prefLastBackup = 'organisr_last_backup_ms';
  static const String _prefAutoBackupEnabled = 'organisr_auto_backup_enabled';
  static const String _backupFileName = 'organisr_backup.osr';

  late Directory _appBaseDir;
  late Directory _databaseDir;
  late Directory _mediaDir;
  late Directory _backupsDir;
  bool _initialized = false;

  Directory get appBaseDir => _appBaseDir;
  Directory get databaseDir => _databaseDir;
  Directory get mediaDir => _mediaDir;
  Directory get backupsDir => _backupsDir;

  String get dbFilePath => p.join(_databaseDir.path, 'organisr.db');
  String get singleBackupFilePath => p.join(_backupsDir.path, _backupFileName);
  File get singleBackupFile => File(singleBackupFilePath);

  Future<void> initialize() async {
    if (_initialized) return;

    if (!kIsWeb && Platform.isAndroid) {
      // Primary location requested: /storage/emulated/0/OrgainSR
      final target = Directory('/storage/emulated/0/OrgainSR');
      try {
        if (!await target.exists()) {
          await target.create(recursive: true);
        }
        _appBaseDir = target;
      } catch (e) {
        debugPrint('Direct /storage/emulated/0/OrgainSR access exception: $e');
        try {
          final ext = await getExternalStorageDirectory();
          _appBaseDir = Directory(p.join(ext?.path ?? (await getApplicationDocumentsDirectory()).path, 'OrgainSR'));
          if (!await _appBaseDir.exists()) {
            await _appBaseDir.create(recursive: true);
          }
        } catch (_) {
          final doc = await getApplicationDocumentsDirectory();
          _appBaseDir = Directory(p.join(doc.path, 'OrgainSR'));
          if (!await _appBaseDir.exists()) {
            await _appBaseDir.create(recursive: true);
          }
        }
      }
    } else {
      // Desktop / Linux / other platform
      final docDir = await getApplicationDocumentsDirectory();
      _appBaseDir = Directory(p.join(docDir.path, 'OrgainSR'));
      if (!await _appBaseDir.exists()) {
        await _appBaseDir.create(recursive: true);
      }
    }

    _databaseDir = Directory(p.join(_appBaseDir.path, 'database'));
    if (!await _databaseDir.exists()) {
      await _databaseDir.create(recursive: true);
    }

    _mediaDir = Directory(p.join(_appBaseDir.path, 'media'));
    if (!await _mediaDir.exists()) {
      await _mediaDir.create(recursive: true);
    }

    _backupsDir = Directory(p.join(_appBaseDir.path, 'backups'));
    if (!await _backupsDir.exists()) {
      await _backupsDir.create(recursive: true);
    }

    _initialized = true;
  }

  Future<String> saveImage(File sourceFile) async {
    await initialize();
    final ext = p.extension(sourceFile.path).toLowerCase();
    final validExt = ext.isEmpty ? '.jpg' : ext;
    final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}$validExt';
    final targetPath = p.join(_mediaDir.path, fileName);

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  Future<bool> checkAndRunWeeklyAutoBackup({Function()? onPreBackup}) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final isAutoBackupEnabled = prefs.getBool(_prefAutoBackupEnabled) ?? true;
    if (!isAutoBackupEnabled) return false;

    final lastBackupMs = prefs.getInt(_prefLastBackup) ?? 0;
    final now = DateTime.now();
    final lastBackupDate = DateTime.fromMillisecondsSinceEpoch(lastBackupMs);
    final daysSinceLastBackup = now.difference(lastBackupDate).inDays;

    if (daysSinceLastBackup >= 7) {
      if (onPreBackup != null) {
        await onPreBackup();
      }
      final backupFile = await createBackup();
      return backupFile != null;
    }
    return false;
  }

  /// Creates or updates the SINGLE unified backup file:
  /// - Avoids storage waste by keeping only one consolidated backup file
  /// - Gathers the full database and all media files
  Future<File?> createBackup() async {
    await initialize();
    try {
      final dbFile = File(dbFilePath);
      if (!await dbFile.exists()) {
        return null;
      }

      final archive = Archive();

      // Add database
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('database/organisr.db', dbBytes.length, dbBytes));

      // Add all media files
      if (await _mediaDir.exists()) {
        final mediaFiles = _mediaDir.listSync(recursive: false);
        for (final entity in mediaFiles) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            final mediaBytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile('media/$fileName', mediaBytes.length, mediaBytes));
          }
        }
      }

      final zipEncoder = ZipEncoder();
      final encodedZip = zipEncoder.encode(archive);
      if (encodedZip.isEmpty) return null;

      final backupFile = File(singleBackupFilePath);
      await backupFile.writeAsBytes(encodedZip);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefLastBackup, DateTime.now().millisecondsSinceEpoch);

      return backupFile;
    } catch (e) {
      debugPrint('Error creating single backup: $e');
      return null;
    }
  }

  /// SMART MERGE RESTORE:
  /// - Restores all historical pages, blocks, and media from backup
  /// - NEVER deletes newly added pages or data created locally!
  /// - Safely merges into live database without data loss
  Future<RestoreResult> restoreAndMergeBackup([File? backupFile]) async {
    await initialize();
    try {
      final targetFile = backupFile ?? singleBackupFile;
      if (!await targetFile.exists()) {
        return const RestoreResult(success: false, errorMessage: 'Backup file does not exist.');
      }

      final bytes = await targetFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      ArchiveFile? dbArchiveFile;
      for (final file in archive) {
        if (file.name == 'database/organisr.db' || file.name == 'organisr.db') {
          dbArchiveFile = file;
          break;
        }
      }

      if (dbArchiveFile == null) {
        return const RestoreResult(success: false, errorMessage: 'Invalid backup: database not found.');
      }

      // Extract backup DB into a temporary file
      final tempDbPath = p.join(_databaseDir.path, 'temp_restore_${DateTime.now().millisecondsSinceEpoch}.db');
      final tempDbFile = File(tempDbPath);
      await tempDbFile.writeAsBytes(dbArchiveFile.content as List<int>);

      // Extract missing media files
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile && filename.startsWith('media/')) {
          final mediaName = p.basename(filename);
          final targetMedia = File(p.join(_mediaDir.path, mediaName));
          if (!await targetMedia.exists()) {
            await targetMedia.writeAsBytes(file.content as List<int>);
          }
        }
      }

      // Open temp backup DB and read its contents
      final backupDb = await openReadOnlyDatabase(tempDbPath);
      final backupPageMaps = await backupDb.query('pages');
      final backupBlockMaps = await backupDb.query('blocks');
      await backupDb.close();

      // Clean up temp DB file
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }

      // Merge into Live Database
      final liveDb = await DatabaseService.instance.database;

      // Get all current page IDs
      final currentPages = await liveDb.query('pages', columns: ['id', 'updated_at']);
      final currentMap = {
        for (var p in currentPages) p['id'] as String: p['updated_at'] as int
      };

      int restoredCount = 0;
      int preservedCount = currentMap.length;

      await liveDb.transaction((txn) async {
        final batch = txn.batch();

        for (final pMap in backupPageMaps) {
          final id = pMap['id'] as String;
          if (!currentMap.containsKey(id)) {
            // Recovered historical page from backup!
            batch.insert('pages', pMap, conflictAlgorithm: ConflictAlgorithm.replace);
            restoredCount++;
          }
        }

        // Get current block IDs
        final currentBlocks = await txn.query('blocks', columns: ['id']);
        final currentBlockIds = {for (var b in currentBlocks) b['id'] as String};

        for (final bMap in backupBlockMaps) {
          final id = bMap['id'] as String;
          if (!currentBlockIds.contains(id)) {
            batch.insert('blocks', bMap, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        await batch.commit(noResult: true);
      });

      return RestoreResult(
        success: true,
        restoredPages: restoredCount,
        preservedPages: preservedCount,
      );
    } catch (e) {
      debugPrint('Error restoring and merging backup: $e');
      return RestoreResult(success: false, errorMessage: e.toString());
    }
  }

  bool hasBackup() {
    return singleBackupFile.existsSync();
  }

  int getBackupSize() {
    if (!hasBackup()) return 0;
    try {
      return singleBackupFile.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  DateTime? getBackupModifiedTime() {
    if (!hasBackup()) return null;
    try {
      return singleBackupFile.lastModifiedSync();
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_prefLastBackup);
    if (ms != null && ms > 0) {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return getBackupModifiedTime();
  }

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutoBackupEnabled) ?? true;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoBackupEnabled, enabled);
  }
}
