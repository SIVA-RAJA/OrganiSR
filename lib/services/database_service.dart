import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/block_model.dart';
import '../models/page_model.dart';
import 'storage_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // If running on desktop (Linux/Windows/macOS), initialize FFI
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    await StorageService.instance.initialize();
    final dbPath = StorageService.instance.dbFilePath;

    return await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pages (
            id TEXT PRIMARY KEY,
            parent_id TEXT,
            title TEXT NOT NULL,
            icon TEXT NOT NULL,
            cover_image TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            position INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES pages (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE blocks (
            id TEXT PRIMARY KEY,
            page_id TEXT NOT NULL,
            type TEXT NOT NULL,
            content TEXT,
            properties TEXT,
            position INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            FOREIGN KEY (page_id) REFERENCES pages (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('CREATE INDEX idx_pages_parent ON pages(parent_id);');
        await db.execute('CREATE INDEX idx_pages_updated ON pages(updated_at DESC);');
        await db.execute('CREATE INDEX idx_blocks_page ON blocks(page_id, position ASC);');
      },
    );
  }

  Future<void> closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> reopenDatabase() async {
    await closeDatabase();
    _db = await _initDatabase();
  }

  // ===================== PAGES CRUD =====================

  Future<List<PageModel>> getRootPages() async {
    final db = await database;
    final maps = await db.query(
      'pages',
      where: 'parent_id IS NULL',
      orderBy: 'position ASC, created_at ASC',
    );
    return maps.map((e) => PageModel.fromMap(e)).toList();
  }

  Future<List<PageModel>> getChildPages(String parentId) async {
    final db = await database;
    final maps = await db.query(
      'pages',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'position ASC, created_at ASC',
    );
    return maps.map((e) => PageModel.fromMap(e)).toList();
  }

  Future<PageModel?> getPage(String id) async {
    final db = await database;
    final maps = await db.query(
      'pages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PageModel.fromMap(maps.first);
  }

  Future<List<PageModel>> getRecentPages({int limit = 10}) async {
    final db = await database;
    final maps = await db.query(
      'pages',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps.map((e) => PageModel.fromMap(e)).toList();
  }

  Future<List<PageModel>> getFavoritePages() async {
    final db = await database;
    final maps = await db.query(
      'pages',
      where: 'is_favorite = 1',
      orderBy: 'updated_at DESC',
    );
    return maps.map((e) => PageModel.fromMap(e)).toList();
  }

  Future<void> insertPage(PageModel page) async {
    final db = await database;
    await db.insert(
      'pages',
      page.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updatePage(PageModel page) async {
    final db = await database;
    await db.update(
      'pages',
      page.toMap(),
      where: 'id = ?',
      whereArgs: [page.id],
    );
  }

  Future<void> deletePage(String pageId) async {
    final db = await database;
    // With foreign_keys = ON and ON DELETE CASCADE, child pages & blocks are deleted automatically
    await db.delete(
      'pages',
      where: 'id = ?',
      whereArgs: [pageId],
    );
  }

  Future<int> getChildCount(String pageId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pages WHERE parent_id = ?',
      [pageId],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<PageModel>> getPageBreadcrumbs(String pageId) async {
    final breadcrumbs = <PageModel>[];
    String? currentId = pageId;

    while (currentId != null) {
      final page = await getPage(currentId);
      if (page != null) {
        breadcrumbs.insert(0, page);
        currentId = page.parentId;
      } else {
        break;
      }
    }
    return breadcrumbs;
  }

  // ===================== BLOCKS CRUD =====================

  Future<List<BlockModel>> getBlocks(String pageId) async {
    final db = await database;
    final maps = await db.query(
      'blocks',
      where: 'page_id = ?',
      whereArgs: [pageId],
      orderBy: 'position ASC, created_at ASC',
    );
    return maps.map((e) => BlockModel.fromMap(e)).toList();
  }

  Future<void> insertBlock(BlockModel block) async {
    final db = await database;
    await db.insert(
      'blocks',
      block.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Touch page updated_at
    await touchPage(block.pageId);
  }

  Future<void> updateBlock(BlockModel block) async {
    final db = await database;
    await db.update(
      'blocks',
      block.toMap(),
      where: 'id = ?',
      whereArgs: [block.id],
    );
    await touchPage(block.pageId);
  }

  Future<void> deleteBlock(String blockId, String pageId) async {
    final db = await database;
    await db.delete(
      'blocks',
      where: 'id = ?',
      whereArgs: [blockId],
    );
    await touchPage(pageId);
  }

  Future<void> reorderBlocks(String pageId, List<BlockModel> blocks) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < blocks.length; i++) {
      batch.update(
        'blocks',
        {'position': i, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [blocks[i].id],
      );
    }
    await batch.commit(noResult: true);
    await touchPage(pageId);
  }

  Future<void> touchPage(String pageId) async {
    final db = await database;
    await db.update(
      'pages',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [pageId],
    );
  }

  // ===================== SEARCH =====================

  Future<List<Map<String, dynamic>>> searchAll(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await database;
    final q = '%${query.trim()}%';

    // Search page titles
    final pageResults = await db.rawQuery('''
      SELECT id, title, icon, updated_at, 'page' as result_type, '' as snippet
      FROM pages
      WHERE title LIKE ?
      ORDER BY updated_at DESC
      LIMIT 20
    ''', [q]);

    // Search block contents
    final blockResults = await db.rawQuery('''
      SELECT b.id, p.id as page_id, p.title as page_title, p.icon as page_icon,
             b.content as snippet, b.type as block_type, b.updated_at, 'block' as result_type
      FROM blocks b
      JOIN pages p ON b.page_id = p.id
      WHERE b.content LIKE ?
      ORDER BY b.updated_at DESC
      LIMIT 30
    ''', [q]);

    return [...pageResults, ...blockResults];
  }

  // ===================== STATS =====================

  Future<Map<String, int>> getStorageStats() async {
    final db = await database;
    final pageCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM pages');
    final blockCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM blocks');
    final pageCount = Sqflite.firstIntValue(pageCountRes) ?? 0;
    final blockCount = Sqflite.firstIntValue(blockCountRes) ?? 0;

    return {
      'pages': pageCount,
      'blocks': blockCount,
    };
  }
}
