import 'package:flutter/material.dart';
import '../models/block_model.dart';

class BlockActionsSheet extends StatelessWidget {
  final BlockModel block;
  final Function(BlockType newType) onTurnInto;
  final VoidCallback onInsertBelow;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const BlockActionsSheet({
    super.key,
    required this.block,
    required this.onTurnInto,
    required this.onInsertBelow,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final wordCount = block.content.trim().isEmpty
        ? 0
        : block.content.trim().split(RegExp(r'\s+')).length;
    final charCount = block.content.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                'Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFEBEBEB) : const Color(0xFF37352F),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Turn into
            ListTile(
              leading: const Icon(Icons.transform, size: 20),
              title: const Text('Turn into'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              dense: true,
              onTap: () {
                Navigator.pop(context);
                _showTurnIntoMenu(context);
              },
            ),

            // Insert below
            ListTile(
              leading: const Icon(Icons.vertical_align_bottom, size: 20),
              title: const Text('Insert below'),
              dense: true,
              onTap: () {
                Navigator.pop(context);
                onInsertBelow();
              },
            ),

            // Duplicate
            ListTile(
              leading: const Icon(Icons.copy, size: 20),
              title: const Text('Duplicate'),
              dense: true,
              onTap: () {
                Navigator.pop(context);
                onDuplicate();
              },
            ),

            // Delete
            ListTile(
              leading: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              dense: true,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),

            const Divider(),

            // Word / Char info footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Text(
                '$wordCount words • $charCount characters',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF777777) : const Color(0xFF999999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTurnIntoMenu(BuildContext context) {
    final types = [
      BlockType.text,
      BlockType.h1,
      BlockType.h2,
      BlockType.h3,
      BlockType.todo,
      BlockType.bullet,
      BlockType.numbered,
      BlockType.quote,
      BlockType.callout,
      BlockType.code,
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Turn into...',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            ...types.map((t) => ListTile(
                  leading: _getTypeIcon(t),
                  title: Text(_getTypeName(t)),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    onTurnInto(t);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _getTypeIcon(BlockType type) {
    switch (type) {
      case BlockType.h1:
        return const Text('H1', style: TextStyle(fontWeight: FontWeight.bold));
      case BlockType.h2:
        return const Text('H2', style: TextStyle(fontWeight: FontWeight.bold));
      case BlockType.h3:
        return const Text('H3', style: TextStyle(fontWeight: FontWeight.bold));
      case BlockType.todo:
        return const Icon(Icons.check_box_outlined, size: 18);
      case BlockType.bullet:
        return const Icon(Icons.format_list_bulleted, size: 18);
      case BlockType.numbered:
        return const Icon(Icons.format_list_numbered, size: 18);
      case BlockType.quote:
        return const Icon(Icons.format_quote, size: 18);
      case BlockType.callout:
        return const Icon(Icons.lightbulb_outline, size: 18);
      case BlockType.code:
        return const Icon(Icons.code, size: 18);
      default:
        return const Text('T', style: TextStyle(fontWeight: FontWeight.bold));
    }
  }

  String _getTypeName(BlockType type) {
    switch (type) {
      case BlockType.h1:
        return 'Heading 1';
      case BlockType.h2:
        return 'Heading 2';
      case BlockType.h3:
        return 'Heading 3';
      case BlockType.todo:
        return 'To-do list';
      case BlockType.bullet:
        return 'Bulleted list';
      case BlockType.numbered:
        return 'Numbered list';
      case BlockType.quote:
        return 'Quote';
      case BlockType.callout:
        return 'Callout';
      case BlockType.code:
        return 'Code';
      default:
        return 'Text';
    }
  }
}
