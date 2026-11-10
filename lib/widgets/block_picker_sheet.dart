import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/block_model.dart';
import '../services/storage_service.dart';

class BlockPickerSheet extends StatelessWidget {
  final Function(BlockType type, {Map<String, dynamic>? properties}) onSelect;
  final VoidCallback? onAddSubpage;

  const BlockPickerSheet({
    super.key,
    required this.onSelect,
    this.onAddSubpage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final basicBlocks = [
      _BlockOption(
        type: BlockType.text,
        title: 'Text',
        subtitle: 'Just start writing with plain text.',
        iconWidget: _badge('T', isDark),
      ),
      _BlockOption(
        type: BlockType.h1,
        title: 'Heading 1',
        subtitle: 'Big section heading.',
        iconWidget: _badge('H1', isDark),
      ),
      _BlockOption(
        type: BlockType.h2,
        title: 'Heading 2',
        subtitle: 'Medium section heading.',
        iconWidget: _badge('H2', isDark),
      ),
      _BlockOption(
        type: BlockType.h3,
        title: 'Heading 3',
        subtitle: 'Small section heading.',
        iconWidget: _badge('H3', isDark),
      ),
      _BlockOption(
        type: BlockType.todo,
        title: 'To-do list',
        subtitle: 'Track tasks with a to-do list.',
        iconWidget: const Icon(Icons.check_box_outlined, size: 20),
      ),
      _BlockOption(
        type: BlockType.bullet,
        title: 'Bulleted list',
        subtitle: 'Create a simple bulleted list.',
        iconWidget: const Icon(Icons.format_list_bulleted, size: 20),
      ),
      _BlockOption(
        type: BlockType.numbered,
        title: 'Numbered list',
        subtitle: 'Create a list with numbering.',
        iconWidget: const Icon(Icons.format_list_numbered, size: 20),
      ),
      _BlockOption(
        type: BlockType.toggle,
        title: 'Toggle list',
        subtitle: 'Toggles hide and show content inside.',
        iconWidget: const Icon(Icons.arrow_right_rounded, size: 24),
      ),
      _BlockOption(
        type: BlockType.subpage,
        title: 'Sub-page',
        subtitle: 'Embed a sub-page inside this page.',
        iconWidget: const Icon(Icons.description_outlined, size: 20),
      ),
    ];

    final mediaBlocks = [
      _BlockOption(
        type: BlockType.image,
        title: 'Image',
        subtitle: 'Upload or embed with an image.',
        iconWidget: const Icon(Icons.image_outlined, size: 20, color: Colors.white),
      ),
      _BlockOption(
        type: BlockType.quote,
        title: 'Quote',
        subtitle: 'Capture a quote or citation.',
        iconWidget: const Icon(Icons.format_quote_rounded, size: 20, color: Colors.white),
      ),
      _BlockOption(
        type: BlockType.callout,
        title: 'Callout',
        subtitle: 'Make writing stand out with an icon callout.',
        iconWidget: const Icon(Icons.call_to_action_outlined, size: 20, color: Colors.white),
      ),
      _BlockOption(
        type: BlockType.divider,
        title: 'Divider',
        subtitle: 'Visually divide blocks with a line.',
        iconWidget: const Icon(Icons.horizontal_rule, size: 20),
      ),
      _BlockOption(
        type: BlockType.code,
        title: 'Code',
        subtitle: 'Capture a code snippet.',
        iconWidget: const Icon(Icons.code_rounded, size: 20),
      ),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Block',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFEBEBEB) : const Color(0xFF37352F),
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                _sectionHeader('BASIC BLOCKS', isDark),
                ...basicBlocks.map((opt) => _buildOptionTile(context, opt, isDark)),

                const SizedBox(height: 8),
                _sectionHeader('MEDIA & ADVANCED', isDark),
                ...mediaBlocks.map((opt) => _buildOptionTile(context, opt, isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 12, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: isDark ? const Color(0xFF777777) : const Color(0xFF888888),
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, _BlockOption option, bool isDark) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282828) : const Color(0xFFEAEAEA),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(child: option.iconWidget),
      ),
      title: Text(
        option.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFEBEBEB) : const Color(0xFF37352F),
        ),
      ),
      subtitle: Text(
        option.subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF8A8A8A) : const Color(0xFF757575),
        ),
      ),
      dense: true,
      onTap: () async {
        Navigator.pop(context);

        if (option.type == BlockType.subpage) {
          onAddSubpage?.call();
          return;
        }

        if (option.type == BlockType.image) {
          _promptImageSource(context);
          return;
        }

        onSelect(option.type);
      },
    );
  }

  void _promptImageSource(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  final savedPath = await StorageService.instance.saveImage(File(picked.path));
                  onSelect(BlockType.image, properties: {'image_path': savedPath, 'caption': ''});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo with Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.camera);
                if (picked != null) {
                  final savedPath = await StorageService.instance.saveImage(File(picked.path));
                  onSelect(BlockType.image, properties: {'image_path': savedPath, 'caption': ''});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFFEBEBEB) : const Color(0xFF37352F),
      ),
    );
  }
}

class _BlockOption {
  final BlockType type;
  final String title;
  final String subtitle;
  final Widget iconWidget;

  _BlockOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.iconWidget,
  });
}
