import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/page_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/icon_helper.dart';
import '../widgets/nested_generator_sheet.dart';
import '../widgets/page_tree_tile.dart';
import 'backup_screen.dart';
import 'page_editor_screen.dart';
import 'page_view_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PageModel> _rootPages = [];
  List<PageModel> _recentPages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPages();
    _checkAutoBackup();
  }

  Future<void> _checkAutoBackup() async {
    await StorageService.instance.checkAndRunWeeklyAutoBackup();
  }

  Future<void> _loadPages() async {
    final roots = await DatabaseService.instance.getRootPages();
    final recents = await DatabaseService.instance.getRecentPages(limit: 6);

    if (roots.isEmpty && recents.isEmpty) {
      await _createInitialSamplePages();
      return;
    }

    if (mounted) {
      setState(() {
        _rootPages = roots;
        _recentPages = recents;
        _isLoading = false;
      });
    }
  }

  Future<void> _createInitialSamplePages() async {
    final now = DateTime.now();
    final sample1 = PageModel(
      id: const Uuid().v4(),
      title: 'Mini Projects',
      icon: 'folder',
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
    final sample2 = PageModel(
      id: const Uuid().v4(),
      title: 'Completed Projects',
      icon: 'archive',
      position: 1,
      createdAt: now,
      updatedAt: now,
    );
    final sample3 = PageModel(
      id: const Uuid().v4(),
      title: 'Personal Notes & Ideas',
      icon: 'journal',
      position: 2,
      createdAt: now,
      updatedAt: now,
    );

    await DatabaseService.instance.insertPage(sample1);
    await DatabaseService.instance.insertPage(sample2);
    await DatabaseService.instance.insertPage(sample3);

    final roots = await DatabaseService.instance.getRootPages();
    final recents = await DatabaseService.instance.getRecentPages(limit: 6);

    if (mounted) {
      setState(() {
        _rootPages = roots;
        _recentPages = recents;
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewRootPage() async {
    final titleController = TextEditingController();
    final createdPage = await showDialog<PageModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Create Page', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Page title...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            filled: true,
            fillColor: const Color(0xFF202020),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onSubmitted: (val) {
            final page = PageModel(
              id: const Uuid().v4(),
              title: val.trim().isEmpty ? 'Untitled' : val.trim(),
              icon: 'page',
              position: _rootPages.length,
            );
            Navigator.pop(ctx, page);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final page = PageModel(
                id: const Uuid().v4(),
                title: titleController.text.trim().isEmpty ? 'Untitled' : titleController.text.trim(),
                icon: 'page',
                position: _rootPages.length,
              );
              Navigator.pop(ctx, page);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (createdPage != null) {
      await DatabaseService.instance.insertPage(createdPage);
      _loadPages();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PageViewScreen(pageId: createdPage.id)),
        ).then((_) => _loadPages());
      }
    }
  }

  void _openCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.note_add_outlined, color: Colors.white),
                title: const Text('New Page', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Create a single root page', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _createNewRootPage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flash_on_rounded, color: Colors.white),
                title: const Text('Generate Nested Structure', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Batch create 10-year journey or multi-level outline', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openNestedGenerator();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNestedGenerator([PageModel? parentPage]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      builder: (_) => NestedGeneratorSheet(
        parentPage: parentPage,
        onGenerated: () => _loadPages(),
      ),
    );
  }

  Future<void> _deletePage(PageModel page) async {
    await DatabaseService.instance.deletePage(page.id);
    _loadPages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        titleSpacing: 16,
        title: Row(
          children: [
            // Unique OrganiSR Logo
            const OrganiSRLogo(size: 24),
            const SizedBox(width: 10),
            const Text(
              'OrganiSR',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 0.5, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 21, color: Colors.white),
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.backup_outlined, size: 20, color: Colors.white),
            tooltip: 'Storage & Backups',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BackupScreen(onDataRestored: _loadPages),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: const Color(0xFF181818),
              onRefresh: _loadPages,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Recents Horizontal Slider
                  if (_recentPages.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 18, right: 18, top: 8, bottom: 8),
                      child: Text(
                        'RECENTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 96,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _recentPages.length,
                        itemBuilder: (context, index) {
                          final page = _recentPages[index];
                          return _buildRecentCard(page);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Pages Tree Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PAGES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20, color: Colors.white),
                          tooltip: 'Add Page',
                          onPressed: _openCreateMenu,
                        ),
                      ],
                    ),
                  ),

                  // Nested Tree List
                  ..._rootPages.map(
                    (page) => PageTreeTile(
                      key: ValueKey(page.id),
                      page: page,
                      depth: 0,
                      onPageTap: (p) {
                        // Tapping a page opens PageViewScreen showing its sub-pages and quick edit option!
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PageViewScreen(pageId: p.id),
                          ),
                        ).then((_) => _loadPages());
                      },
                      onAddChild: (parent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PageViewScreen(pageId: parent.id),
                          ),
                        ).then((_) => _loadPages());
                      },
                      onBatchGenerate: (p) => _openNestedGenerator(p),
                      onPageDelete: _deletePage,
                      onPageEdit: (p) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PageEditorScreen(pageId: p.id),
                          ),
                        ).then((_) => _loadPages());
                      },
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Create or Generate',
        onPressed: _openCreateMenu,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildRecentCard(PageModel page) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PageViewScreen(pageId: page.id),
          ),
        ).then((_) => _loadPages());
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF222222)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PageIconHelper.renderIcon(page.icon, size: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.title.isEmpty ? 'Untitled' : page.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d').format(page.updatedAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
