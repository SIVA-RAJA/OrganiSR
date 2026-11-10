import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../theme/notion_theme.dart';

class EditorToolbar extends StatefulWidget {
  final VoidCallback onAddBlock;
  final VoidCallback onTurnInto;
  final Function(String imagePath) onInsertImage;
  final VoidCallback onInsertTodo;
  final VoidCallback onInsertHeading;
  final VoidCallback onInsertBullet;
  final Function(String colorHex) onTextColorSelected;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onDismissKeyboard;

  const EditorToolbar({
    super.key,
    required this.onAddBlock,
    required this.onTurnInto,
    required this.onInsertImage,
    required this.onInsertTodo,
    required this.onInsertHeading,
    required this.onInsertBullet,
    required this.onTextColorSelected,
    this.onUndo,
    this.onRedo,
    required this.onDismissKeyboard,
  });

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {
  bool _showColorPicker = false;

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final savedPath = await StorageService.instance.saveImage(File(picked.path));
      widget.onInsertImage(savedPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text Color Highlighting Strip (When toggled)
        if (_showColorPicker)
          Container(
            height: 40,
            color: const Color(0xFF141414),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Text(
                  'Highlight:',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: NotionTheme.highlightColors.length,
                    separatorBuilder: (context, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final hc = NotionTheme.highlightColors[index];
                      return Center(
                        child: InkWell(
                          onTap: () {
                            final hex = '#${hc.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                            widget.onTextColorSelected(hc.name == 'Default' ? '' : hex);
                            setState(() => _showColorPicker = false);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: hc.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hc.name == 'Default' ? Colors.grey : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: hc.name == 'Default'
                                ? const Center(child: Icon(Icons.format_color_reset, size: 12, color: Colors.black))
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.white60),
                  onPressed: () => setState(() => _showColorPicker = false),
                ),
              ],
            ),
          ),

        // Main Toolbar
        Container(
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            border: Border(
              top: BorderSide(
                color: Color(0xFF262626),
                width: 0.8,
              ),
            ),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            children: [
              _toolbarButton(
                icon: Icons.add,
                tooltip: 'Add block',
                onPressed: widget.onAddBlock,
              ),

              IconButton(
                icon: const Text(
                  'Aa',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                tooltip: 'Change style',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onTurnInto,
              ),

              // Text Color Highlight Palette Button
              IconButton(
                icon: Icon(
                  Icons.palette_outlined,
                  size: 19,
                  color: _showColorPicker ? Colors.white : Colors.white70,
                ),
                tooltip: 'Text Color Highlight',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _showColorPicker = !_showColorPicker),
              ),

              _toolbarButton(
                icon: Icons.image_outlined,
                tooltip: 'Insert image',
                onPressed: () => _pickImage(context),
              ),

              _toolbarButton(
                icon: Icons.check_box_outlined,
                tooltip: 'To-do list',
                onPressed: widget.onInsertTodo,
              ),

              IconButton(
                icon: const Text(
                  'H',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                tooltip: 'Heading',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onInsertHeading,
              ),

              _toolbarButton(
                icon: Icons.format_list_bulleted,
                tooltip: 'Bullet list',
                onPressed: widget.onInsertBullet,
              ),

              _toolbarButton(
                icon: Icons.undo,
                tooltip: 'Undo',
                onPressed: widget.onUndo,
              ),

              _toolbarButton(
                icon: Icons.redo,
                tooltip: 'Redo',
                onPressed: widget.onRedo,
              ),

              const SizedBox(width: 8),

              _toolbarButton(
                icon: Icons.keyboard_hide_outlined,
                tooltip: 'Hide keyboard',
                onPressed: widget.onDismissKeyboard,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 19),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: Colors.white70,
      onPressed: onPressed,
    );
  }
}
