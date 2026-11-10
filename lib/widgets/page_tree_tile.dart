import 'package:flutter/material.dart';
import '../models/page_model.dart';
import '../services/database_service.dart';
import 'icon_helper.dart';

class PageTreeTile extends StatefulWidget {
  final PageModel page;
  final int depth;
  final Function(PageModel page) onPageTap;
  final Function(PageModel parentPage) onAddChild;
  final Function(PageModel page) onBatchGenerate;
  final Function(PageModel page) onPageDelete;
  final Function(PageModel page)? onPageEdit;

  const PageTreeTile({
    super.key,
    required this.page,
    this.depth = 0,
    required this.onPageTap,
    required this.onAddChild,
    required this.onBatchGenerate,
    required this.onPageDelete,
    this.onPageEdit,
  });

  @override
  State<PageTreeTile> createState() => _PageTreeTileState();
}

class _PageTreeTileState extends State<PageTreeTile> {
  bool _isExpanded = false;
  List<PageModel> _children = [];
  bool _isLoading = false;
  int _childCount = 0;

  @override
  void initState() {
    super.initState();
    _checkChildCount();
  }

  @override
  void didUpdateWidget(covariant PageTreeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.updatedAt != widget.page.updatedAt) {
      _checkChildCount();
      if (_isExpanded) {
        _loadChildren();
      }
    }
  }

  Future<void> _checkChildCount() async {
    final count = await DatabaseService.instance.getChildCount(widget.page.id);
    if (mounted) {
      setState(() {
        _childCount = count;
      });
    }
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    final kids = await DatabaseService.instance.getChildPages(widget.page.id);
    if (mounted) {
      setState(() {
        _children = kids;
        _childCount = kids.length;
        _isLoading = false;
      });
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded && _children.isEmpty) {
      _loadChildren();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onPageTap(widget.page),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.only(
              left: 12.0 + (widget.depth * 18.0),
              right: 8.0,
              top: 5.0,
              bottom: 5.0,
            ),
            child: Row(
              children: [
                // Expand / Collapse Chevron
                SizedBox(
                  width: 24,
                  height: 24,
                  child: _childCount > 0
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.chevron_right_rounded,
                            color: isDark
                                ? const Color(0xFF9B9B9B)
                                : const Color(0xFF787774),
                          ),
                          onPressed: _toggleExpand,
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(width: 4),

                // Page Icon
                PageIconHelper.renderIcon(
                  widget.page.icon,
                  size: 16,
                  isFolder: _childCount > 0,
                  color: isDark ? const Color(0xFFC0C0C0) : const Color(0xFF4A4A4A),
                ),

                const SizedBox(width: 8),

                // Page Title
                Expanded(
                  child: Text(
                    widget.page.title.isEmpty ? 'Untitled' : widget.page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFEBEBEB)
                          : const Color(0xFF37352F),
                    ),
                  ),
                ),

                // Child count badge (if has children)
                if (_childCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_childCount',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF888888)
                            : const Color(0xFF888888),
                      ),
                    ),
                  ),

                // Add Child button '+'
                IconButton(
                  icon: const Icon(Icons.add, size: 17),
                  color: isDark
                      ? const Color(0xFF8A8A8A)
                      : const Color(0xFF787774),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Add sub-page',
                  onPressed: () => widget.onAddChild(widget.page),
                ),

                // More Options button '...'
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 17),
                  color: isDark
                      ? const Color(0xFF8A8A8A)
                      : const Color(0xFF787774),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Options',
                  onPressed: () => _showPageOptionsSheet(context),
                ),
              ],
            ),
          ),
        ),

        // Recursive Nested Children
        if (_isExpanded) ...[
          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(
                left: 36.0 + (widget.depth * 18.0),
                top: 4,
                bottom: 4,
              ),
              child: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ..._children.map(
              (child) => PageTreeTile(
                key: ValueKey(child.id),
                page: child,
                depth: widget.depth + 1,
                onPageTap: widget.onPageTap,
                onAddChild: (parent) async {
                  await widget.onAddChild(parent);
                  _loadChildren();
                },
                onBatchGenerate: widget.onBatchGenerate,
                onPageDelete: (deleted) async {
                  await widget.onPageDelete(deleted);
                  _loadChildren();
                },
                onPageEdit: widget.onPageEdit,
              ),
            ),
        ],
      ],
    );
  }

  void _showPageOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      PageIconHelper.renderIcon(widget.page.icon, size: 20, isFolder: _childCount > 0),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.page.title.isEmpty ? 'Untitled' : widget.page.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                ListTile(
                  leading: const Icon(Icons.add, size: 20),
                  title: const Text('Add sub-page'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onAddChild(widget.page);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.flash_on_rounded, size: 20, color: Colors.white),
                  title: const Text('Generate Nested Structure'),
                  subtitle: const Text('Batch generate journey, days, or outline', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onBatchGenerate(widget.page);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  title: const Text('Delete page', style: TextStyle(color: Colors.redAccent)),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete page?'),
        content: Text(
          'Are you sure you want to delete "${widget.page.title}" and all its sub-pages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onPageDelete(widget.page);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
