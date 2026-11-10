import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/block_model.dart';
import '../models/page_model.dart';
import 'database_service.dart';

enum LevelType {
  years,
  months,
  days,
  numberRange,
  customList,
}

class HierarchyLevelConfig {
  LevelType type;
  int startNum;
  int endNum;
  String prefix;
  String customNamesRaw;
  String iconKey;

  HierarchyLevelConfig({
    required this.type,
    this.startNum = 1,
    this.endNum = 10,
    this.prefix = '',
    this.customNamesRaw = '',
    this.iconKey = 'folder',
  });

  List<String> getItems({int? contextYear, int? contextMonth}) {
    switch (type) {
      case LevelType.years:
        final s = startNum;
        final e = endNum >= s ? endNum : s;
        return List.generate(e - s + 1, (i) => '${prefix.isEmpty ? '' : '$prefix '}${s + i}');

      case LevelType.months:
        return const [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];

      case LevelType.days:
        final year = contextYear ?? DateTime.now().year;
        final month = contextMonth ?? 1;
        final totalDays = DateTime(year, month + 1, 0).day;
        final monthNames = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        final monthStr = monthNames[(month - 1).clamp(0, 11)];

        return List.generate(totalDays, (i) {
          final day = i + 1;
          final date = DateTime(year, month, day);
          final weekday = DateFormat('E').format(date);
          final dayPadded = day.toString().padLeft(2, '0');
          return '$monthStr $dayPadded ($weekday)';
        });

      case LevelType.numberRange:
        final s = startNum;
        final e = endNum >= s ? endNum : s;
        return List.generate(e - s + 1, (i) => '${prefix.isEmpty ? '' : '$prefix '}${s + i}');

      case LevelType.customList:
        if (customNamesRaw.trim().isEmpty) return ['Item 1'];
        return customNamesRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    }
  }
}

class HierarchyGenerator {
  static final HierarchyGenerator instance = HierarchyGenerator._internal();
  HierarchyGenerator._internal();

  bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Unified Universal Hierarchy Generator:
  /// - Builds unlimited nested levels
  /// - Automatically numbers leaf page notes (e.g. DAY 1..3652) inside the note content
  /// - Injects common note templates
  /// - Executes fast in a single SQLite transaction with batch flushing
  Future<PageModel> generateUnifiedHierarchy({
    required String rootTitle,
    String rootIcon = 'calendar',
    String? parentPageId,
    required List<HierarchyLevelConfig> levels,
    bool addLeafNoteHeader = true,
    String leafHeaderFormat = 'DAY {n}',
    int leafHeaderStart = 1,
    String? commonNoteTemplate,
    Function(double progress, String status)? onProgress,
  }) async {
    final db = await DatabaseService.instance.database;
    final uuid = const Uuid();
    final now = DateTime.now();

    final rootPage = PageModel(
      id: uuid.v4(),
      parentId: parentPageId,
      title: rootTitle,
      icon: rootIcon,
      position: 0,
      createdAt: now,
      updatedAt: now,
    );

    int leafCounter = leafHeaderStart;
    int totalEstimatedPages = 1;

    // Estimate total pages for progress calculation
    int currentMultiplier = 1;
    for (final lvl in levels) {
      int count = 1;
      if (lvl.type == LevelType.years) {
        count = (lvl.endNum - lvl.startNum + 1).clamp(1, 100);
      } else if (lvl.type == LevelType.months) {
        count = 12;
      } else if (lvl.type == LevelType.days) {
        count = 31;
      } else if (lvl.type == LevelType.numberRange) {
        count = (lvl.endNum - lvl.startNum + 1).clamp(1, 500);
      } else if (lvl.type == LevelType.customList) {
        count = lvl.customNamesRaw.split(',').length.clamp(1, 100);
      }
      currentMultiplier *= count;
      totalEstimatedPages += currentMultiplier;
    }

    int createdPagesCount = 0;

    await db.transaction((txn) async {
      // 1. Insert root page
      await txn.insert('pages', rootPage.toMap());
      createdPagesCount++;
      onProgress?.call(createdPagesCount / totalEstimatedPages, 'Created root: $rootTitle');

      Batch batch = txn.batch();
      int batchCount = 0;

      Future<void> flushIfNeeded([bool force = false]) async {
        if (batchCount >= 300 || (force && batchCount > 0)) {
          await batch.commit(noResult: true);
          batch = txn.batch();
          batchCount = 0;
        }
      }

      // Recursive builder
      Future<void> buildLevel({
        required String currentParentId,
        required int levelIndex,
        int? inheritedYear,
        int? inheritedMonth,
      }) async {
        if (levelIndex >= levels.length) return;

        final config = levels[levelIndex];
        final isLeaf = levelIndex == levels.length - 1;
        final items = config.getItems(
          contextYear: inheritedYear,
          contextMonth: inheritedMonth,
        );

        for (int i = 0; i < items.length; i++) {
          final itemTitle = items[i];
          final pageId = uuid.v4();

          int? yearForNext = inheritedYear;
          int? monthForNext = inheritedMonth;

          if (config.type == LevelType.years) {
            yearForNext = config.startNum + i;
          } else if (config.type == LevelType.months) {
            monthForNext = i + 1;
          }

          final page = PageModel(
            id: pageId,
            parentId: currentParentId,
            title: itemTitle,
            icon: config.iconKey,
            position: i,
            createdAt: now,
            updatedAt: now,
          );

          batch.insert('pages', page.toMap());
          batchCount++;

          // If this is a leaf page, add note blocks (DAY 1 header + optional template)
          if (isLeaf) {
            int blockPos = 0;
            if (addLeafNoteHeader) {
              final headerText = leafHeaderFormat.replaceAll('{n}', '$leafCounter');
              leafCounter++;

              final headerBlock = BlockModel(
                id: uuid.v4(),
                pageId: pageId,
                type: BlockType.h1,
                content: headerText,
                position: blockPos++,
              );
              batch.insert('blocks', headerBlock.toMap());
              batchCount++;
            }

            if (commonNoteTemplate != null && commonNoteTemplate.trim().isNotEmpty) {
              final lines = commonNoteTemplate.split('\n');
              for (final line in lines) {
                final trimmed = line.trim();
                BlockType bType = BlockType.text;
                String bContent = line;

                if (trimmed.startsWith('# ')) {
                  bType = BlockType.h1;
                  bContent = trimmed.substring(2);
                } else if (trimmed.startsWith('## ')) {
                  bType = BlockType.h2;
                  bContent = trimmed.substring(3);
                } else if (trimmed.startsWith('### ')) {
                  bType = BlockType.h3;
                  bContent = trimmed.substring(4);
                } else if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('[ ] ')) {
                  bType = BlockType.todo;
                  bContent = trimmed.replaceAll(RegExp(r'^(- \[ \] |\[ \] )'), '');
                } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
                  bType = BlockType.bullet;
                  bContent = trimmed.substring(2);
                } else if (trimmed == '---') {
                  bType = BlockType.divider;
                  bContent = '';
                }

                final contentBlock = BlockModel(
                  id: uuid.v4(),
                  pageId: pageId,
                  type: bType,
                  content: bContent,
                  position: blockPos++,
                );
                batch.insert('blocks', contentBlock.toMap());
                batchCount++;
              }
            }
          }

          createdPagesCount++;
          await flushIfNeeded();

          if (createdPagesCount % 100 == 0) {
            final progress = (createdPagesCount / totalEstimatedPages).clamp(0.0, 0.98);
            onProgress?.call(progress, 'Generating $itemTitle...');
          }

          // Recurse to next level
          if (!isLeaf) {
            await buildLevel(
              currentParentId: pageId,
              levelIndex: levelIndex + 1,
              inheritedYear: yearForNext,
              inheritedMonth: monthForNext,
            );
          }
        }
      }

      await buildLevel(currentParentId: rootPage.id, levelIndex: 0);
      await flushIfNeeded(true);
    });

    onProgress?.call(1.0, 'Generation complete!');
    return rootPage;
  }
}
