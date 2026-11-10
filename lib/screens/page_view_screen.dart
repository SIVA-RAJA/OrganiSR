import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/block_model.dart';
import '../models/page_model.dart';
import '../services/database_service.dart';
import '../widgets/icon_helper.dart';
import '../widgets/nested_generator_sheet.dart';
import 'page_editor_screen.dart';

class PageViewScreen extends StatefulWidget {
  final String pageId;

  const PageViewScreen({super.key, required this.pageId});

  @override
  State<PageViewScreen> createState() => _PageViewScreenState();
}

class _PageViewScreenState extends State<PageViewScreen> {
  PageModel? _page;
  List<PageModel> _subpages = [];
  List<BlockModel> _blocks = [];
  List<PageModel> _breadcrumbs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    final page = await DatabaseService.instance.getPage(widget.pageId);
    if (page == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final children = await DatabaseService.instance.getChildPages(widget.pageId);
    final blocks = await DatabaseService.instance.getBlocks(widget.pageId);
    final breadcrumbs = await DatabaseService.instance.getPageBreadcrumbs(widget.pageId);

    if (mounted) {
      setState(() {
        _page = page;
        _subpages = children;
        _blocks = blocks;
        _breadcrumbs = breadcrumbs;
        _isLoading = false;
      });
    }
  }

  void _openEditor() {
    if (_page == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PageEditorScreen(pageId: _page!.id),
      ),
    ).then((_) => _loadPage());
  }

  Future<void> _createNewSubpage() async {
    final titleController = TextEditingController();
    final newPage = await showDialog<PageModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('New Sub-page', style: TextStyle(color: Colors.white, fontSize: 16)),
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
              parentId: widget.pageId,
              title: val.trim().isEmpty ? 'Untitled' : val.trim(),
              icon: 'page',
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
                parentId: widget.pageId,
                title: titleController.text.trim().isEmpty ? 'Untitled' : titleController.text.trim(),
                icon: 'page',
              );
              Navigator.pop(ctx, page);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (newPage != null) {
      await DatabaseService.instance.insertPage(newPage);
      _loadPage();
    }
  }

  void _openNestedGenerator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      builder: (ctx) => NestedGeneratorSheet(
        parentPage: _page,
        onGenerated: () => _loadPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      );
    }

    final page = _page!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildBreadcrumbsHeader(),
        actions: [
          // Direct prominent edit button
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 24, color: Colors.white),
            tooltip: 'Edit Page Notes',
            onPressed: _openEditor,
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            tooltip: 'Options',
            onPressed: () => _showPageMenu(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        children: [
          // Cover Image if any
          if (page.coverImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.file(File(page.coverImage!), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Page Header Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PageIconHelper.renderIcon(page.icon, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.title.isEmpty ? 'Untitled' : page.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Updated ${DateFormat('MMM d, yyyy • HH:mm').format(page.updatedAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Note Content Preview & Quick Edit Card
          _buildNotePreviewCard(),

          const SizedBox(height: 24),

          // Sub-pages Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'NESTED PAGES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_subpages.length}',
                      style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.flash_on_rounded, size: 18, color: Colors.white),
                    tooltip: 'Generate Nested Structure',
                    visualDensity: VisualDensity.compact,
                    onPressed: _openNestedGenerator,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20, color: Colors.white),
                    tooltip: 'Add Sub-page',
                    visualDensity: VisualDensity.compact,
                    onPressed: _createNewSubpage,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Subpages List
          if (_subpages.isEmpty)
            _buildEmptySubpagesState()
          else
            ..._subpages.map((child) => _buildSubpageItem(child)),

          const SizedBox(height: 60),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
        icon: const Icon(Icons.edit, size: 18),
        label: const Text('Edit Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openEditor,
      ),
    );
  }

  Widget _buildNotePreviewCard() {
    final hasContent = _blocks.any((b) => b.content.trim().isNotEmpty);

    return InkWell(
      onTap: _openEditor,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notes_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      'Page Notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Tap to Edit →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!hasContent)
              Text(
                'No notes written yet. Tap to start writing...',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              )
            else
              ..._blocks
                  .where((b) => b.content.trim().isNotEmpty)
                  .take(4)
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          b.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: b.type == BlockType.h1 ? 15 : 13,
                            fontWeight: b.type == BlockType.h1 || b.type == BlockType.h2
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      )),
          ],
        ),
      ),
    );
  }

  Widget _buildSubpageItem(PageModel child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF202020),
            borderRadius: BorderRadius.circular(6),
          ),
          child: PageIconHelper.renderIcon(child.icon, size: 18),
        ),
        title: Text(
          child.title.isEmpty ? 'Untitled' : child.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        subtitle: Text(
          DateFormat('MMM d').format(child.updatedAt),
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF666666)),
        onTap: () {
          // Touching a sub-page enters that sub-page's nested view!
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PageViewScreen(pageId: child.id),
            ),
          ).then((_) => _loadPage());
        },
      ),
    );
  }

  Widget _buildEmptySubpagesState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open, size: 32, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          Text(
            'No nested pages inside this page',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('Add Sub-page', style: TextStyle(color: Colors.white)),
                onPressed: _createNewSubpage,
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.flash_on, size: 16, color: Colors.white),
                label: const Text('Generate Batch', style: TextStyle(color: Colors.white)),
                onPressed: _openNestedGenerator,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbsHeader() {
    if (_breadcrumbs.length <= 1) {
      return Text(
        _page?.title ?? '',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _breadcrumbs.map((crumb) {
          final isCurrent = crumb.id == widget.pageId;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: isCurrent
                    ? null
                    : () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PageViewScreen(pageId: crumb.id),
                          ),
                        );
                      },
                child: Text(
                  crumb.title.isEmpty ? 'Untitled' : crumb.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              if (crumb.id != _breadcrumbs.last.id)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text('/', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.25))),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showPageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Colors.white),
              title: const Text('Edit Page Notes', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _openEditor();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flash_on_rounded, color: Colors.white),
              title: const Text('Generate Nested Structure', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Generate days/months or multi-level pages', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _openNestedGenerator();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete page', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final navigator = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: const Color(0xFF141414),
                    title: const Text('Delete Page?', style: TextStyle(color: Colors.white)),
                    content: const Text('All content and nested sub-pages will be deleted.', style: TextStyle(color: Colors.grey)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await DatabaseService.instance.deletePage(widget.pageId);
                  if (mounted) navigator.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
