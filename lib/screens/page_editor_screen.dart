import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/block_model.dart';
import '../models/page_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../widgets/block_picker_sheet.dart';
import '../widgets/block_widget.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/icon_helper.dart';
import '../widgets/nested_generator_sheet.dart';

class PageEditorScreen extends StatefulWidget {
  final String pageId;

  const PageEditorScreen({super.key, required this.pageId});

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  PageModel? _page;
  List<BlockModel> _blocks = [];
  List<PageModel> _breadcrumbs = [];
  bool _isLoading = true;

  late TextEditingController _titleController;
  Timer? _titleDebounce;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _titleFocusNode = FocusNode();

  String? _activeBlockId;

  // Undo stack for blocks
  final List<List<BlockModel>> _undoHistory = [];
  final List<List<BlockModel>> _redoHistory = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _loadPageData();
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    final page = await DatabaseService.instance.getPage(widget.pageId);
    if (page == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final blocks = await DatabaseService.instance.getBlocks(widget.pageId);
    final breadcrumbs = await DatabaseService.instance.getPageBreadcrumbs(widget.pageId);

    // If page is completely empty, add an initial blank text block
    if (blocks.isEmpty) {
      final initialBlock = BlockModel(
        id: const Uuid().v4(),
        pageId: widget.pageId,
        type: BlockType.text,
        content: '',
        position: 0,
      );
      await DatabaseService.instance.insertBlock(initialBlock);
      blocks.add(initialBlock);
    }

    if (mounted) {
      setState(() {
        _page = page;
        _blocks = blocks;
        _breadcrumbs = breadcrumbs;
        _titleController.text = page.title;
        _isLoading = false;
      });
    }
  }

  void _onTitleChanged(String text) {
    if (_page == null) return;
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 300), () async {
      final updated = _page!.copyWith(title: text.isEmpty ? 'Untitled' : text);
      await DatabaseService.instance.updatePage(updated);
      setState(() {
        _page = updated;
      });
    });
  }

  void _recordHistory() {
    _undoHistory.add(List<BlockModel>.from(_blocks));
    if (_undoHistory.length > 20) {
      _undoHistory.removeAt(0);
    }
    _redoHistory.clear();
  }

  Future<void> _updateBlock(BlockModel updatedBlock) async {
    _activeBlockId = updatedBlock.id;
    _recordHistory();
    final index = _blocks.indexWhere((b) => b.id == updatedBlock.id);
    if (index != -1) {
      setState(() {
        _blocks[index] = updatedBlock;
      });
      await DatabaseService.instance.updateBlock(updatedBlock);
    }
  }

  void _applyTextColorToActiveBlock(String colorHex) {
    if (_blocks.isEmpty) return;
    int targetIndex = _blocks.indexWhere((b) => b.id == _activeBlockId);
    if (targetIndex == -1) {
      targetIndex = _blocks.length - 1;
    }
    final block = _blocks[targetIndex];
    final updatedProps = Map<String, dynamic>.from(block.properties);
    if (colorHex.isEmpty) {
      updatedProps.remove('text_color');
    } else {
      updatedProps['text_color'] = colorHex;
    }
    _updateBlock(block.copyWith(properties: updatedProps));
  }

  Future<void> _deleteBlock(BlockModel block) async {
    _recordHistory();
    setState(() {
      _blocks.removeWhere((b) => b.id == block.id);
    });
    await DatabaseService.instance.deleteBlock(block.id, widget.pageId);

    // Ensure at least one block exists
    if (_blocks.isEmpty) {
      await _insertBlock(BlockType.text);
    }
  }

  Future<void> _insertBlock(
    BlockType type, {
    int? atIndex,
    String content = '',
    Map<String, dynamic>? properties,
  }) async {
    _recordHistory();
    final newBlock = BlockModel(
      id: const Uuid().v4(),
      pageId: widget.pageId,
      type: type,
      content: content,
      properties: properties ?? {},
      position: atIndex ?? _blocks.length,
    );

    setState(() {
      if (atIndex != null && atIndex >= 0 && atIndex <= _blocks.length) {
        _blocks.insert(atIndex, newBlock);
      } else {
        _blocks.add(newBlock);
      }
    });

    await DatabaseService.instance.insertBlock(newBlock);
    await DatabaseService.instance.reorderBlocks(widget.pageId, _blocks);
  }

  Future<void> _duplicateBlock(BlockModel block) async {
    _recordHistory();
    final index = _blocks.indexWhere((b) => b.id == block.id);
    final copy = block.copyWith(
      id: const Uuid().v4(),
      position: index + 1,
    );

    setState(() {
      _blocks.insert(index + 1, copy);
    });

    await DatabaseService.instance.insertBlock(copy);
    await DatabaseService.instance.reorderBlocks(widget.pageId, _blocks);
  }

  Future<void> _turnBlockInto(BlockModel block, BlockType newType) async {
    _recordHistory();
    final index = _blocks.indexWhere((b) => b.id == block.id);
    if (index != -1) {
      final updated = block.copyWith(type: newType);
      setState(() {
        _blocks[index] = updated;
      });
      await DatabaseService.instance.updateBlock(updated);
    }
  }

  Future<void> _pickPageIcon() async {
    final selected = await PageIconHelper.showIconPicker(
      context,
      currentIcon: _page?.icon,
    );

    if (selected != null && _page != null) {
      final updated = _page!.copyWith(icon: selected);
      await DatabaseService.instance.updatePage(updated);
      setState(() => _page = updated);
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && _page != null) {
      final savedPath = await StorageService.instance.saveImage(File(picked.path));
      final updated = _page!.copyWith(coverImage: savedPath);
      await DatabaseService.instance.updatePage(updated);
      setState(() => _page = updated);
    }
  }

  Future<void> _removeCoverImage() async {
    if (_page == null) return;
    final updated = _page!.copyWith(clearCover: true);
    await DatabaseService.instance.updatePage(updated);
    setState(() => _page = updated);
  }

  void _openBlockPicker({int? atIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => BlockPickerSheet(
        onSelect: (type, {properties}) {
          _insertBlock(type, atIndex: atIndex, properties: properties);
        },
        onAddSubpage: () => _createInlineSubpage(atIndex: atIndex),
      ),
    );
  }

  Future<void> _createInlineSubpage({int? atIndex}) async {
    final newSubpage = PageModel(
      id: const Uuid().v4(),
      parentId: widget.pageId,
      title: 'Untitled Sub-page',
      icon: 'page',
    );
    await DatabaseService.instance.insertPage(newSubpage);
    await _insertBlock(
      BlockType.subpage,
      atIndex: atIndex,
      content: newSubpage.title,
      properties: {'page_id': newSubpage.id},
    );
  }

  void _undo() {
    if (_undoHistory.isNotEmpty) {
      _redoHistory.add(List<BlockModel>.from(_blocks));
      final prev = _undoHistory.removeLast();
      setState(() {
        _blocks = prev;
      });
      DatabaseService.instance.reorderBlocks(widget.pageId, prev);
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      _undoHistory.add(List<BlockModel>.from(_blocks));
      final next = _redoHistory.removeLast();
      setState(() {
        _blocks = next;
      });
      DatabaseService.instance.reorderBlocks(widget.pageId, next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final page = _page!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildBreadcrumbsHeader(isDark),
        actions: [
          IconButton(
            icon: Icon(
              page.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: page.isFavorite ? Colors.amber : (isDark ? Colors.white70 : Colors.black54),
              size: 22,
            ),
            tooltip: 'Favorite',
            onPressed: () async {
              final updated = page.copyWith(isFavorite: !page.isFavorite);
              await DatabaseService.instance.updatePage(updated);
              setState(() => _page = updated);
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'Page Options',
            onPressed: () => _showPageMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 60),
              children: [
                // Cover Image
                if (page.coverImage != null) _buildCoverImage(isDark),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Icon
                      InkWell(
                        onTap: _pickPageIcon,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6.0),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF303030)),
                          ),
                          child: PageIconHelper.renderIcon(page.icon, size: 28),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Large Title
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF191919),
                        ),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Untitled',
                          hintStyle: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: isDark ? const Color(0xFF505050) : const Color(0xFFBDBDBD),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: _onTitleChanged,
                      ),

                      const SizedBox(height: 16),

                      // Blocks List
                      ...List.generate(_blocks.length, (index) {
                        final block = _blocks[index];
                        return BlockWidget(
                          key: ValueKey(block.id),
                          block: block,
                          index: index,
                          onUpdate: _updateBlock,
                          onDelete: () => _deleteBlock(block),
                          onTurnInto: (newType) => _turnBlockInto(block, newType),
                          onInsertBelow: () => _openBlockPicker(atIndex: index + 1),
                          onDuplicate: () => _duplicateBlock(block),
                          onEnterPressed: (b) => _insertBlock(BlockType.text, atIndex: index + 1),
                          onNavigateToPage: (b) {
                            if (b.targetPageId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => PageEditorScreen(pageId: b.targetPageId!),
                                ),
                              ).then((_) => _loadPageData());
                            }
                          },
                        );
                      }),

                      const SizedBox(height: 16),

                      // Bottom "Add Block" tap area
                      InkWell(
                        onTap: () => _openBlockPicker(),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 18,
                                color: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tap to add block or media...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Docked Notion Accessory Toolbar above keyboard
          EditorToolbar(
            onAddBlock: () => _openBlockPicker(),
            onTurnInto: () {
              if (_blocks.isNotEmpty) {
                final targetIndex = _activeBlockId != null
                    ? _blocks.indexWhere((b) => b.id == _activeBlockId)
                    : _blocks.length - 1;
                final idx = targetIndex != -1 ? targetIndex : _blocks.length - 1;
                _turnBlockInto(_blocks[idx], BlockType.h2);
              }
            },
            onTextColorSelected: _applyTextColorToActiveBlock,
            onInsertImage: (path) {
              _insertBlock(BlockType.image, properties: {'image_path': path, 'caption': ''});
            },
            onInsertTodo: () => _insertBlock(BlockType.todo),
            onInsertHeading: () => _insertBlock(BlockType.h2),
            onInsertBullet: () => _insertBlock(BlockType.bullet),
            onUndo: _undoHistory.isNotEmpty ? _undo : null,
            onRedo: _redoHistory.isNotEmpty ? _redo : null,
            onDismissKeyboard: () => FocusScope.of(context).unfocus(),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbsHeader(bool isDark) {
    if (_breadcrumbs.length <= 1) {
      return Text(
        _page?.title ?? '',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                            builder: (ctx) => PageEditorScreen(pageId: crumb.id),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Text(
                    crumb.title.isEmpty ? 'Untitled' : crumb.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              ),
              if (crumb.id != _breadcrumbs.last.id)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '/',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCoverImage(bool isDark) {
    final file = File(_page!.coverImage!);
    return Stack(
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: file.existsSync()
              ? Image.file(file, fit: BoxFit.cover)
              : Container(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.sync, color: Colors.white, size: 14),
                  label: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                  onPressed: _pickCoverImage,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  onPressed: _removeCoverImage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(_page?.coverImage == null ? 'Add cover image' : 'Change cover image'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCoverImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('Change icon / emoji'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPageIcon();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flash_on_rounded, color: Colors.white),
              title: const Text('Generate Nested Structure here'),
              subtitle: const Text('Generate years/months/days or text outline'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF141414),
                  builder: (_) => NestedGeneratorSheet(
                    parentPage: _page,
                    onGenerated: () => _loadPageData(),
                  ),
                );
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
                    title: const Text('Delete Page?'),
                    content: const Text('All content and nested sub-pages will be deleted.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
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
                  if (mounted) {
                    navigator.pop();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
