import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/block_model.dart';
import '../services/storage_service.dart';

class ImageBlockWidget extends StatefulWidget {
  final BlockModel block;
  final Function(BlockModel updatedBlock) onUpdate;
  final VoidCallback onDelete;

  const ImageBlockWidget({
    super.key,
    required this.block,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<ImageBlockWidget> createState() => _ImageBlockWidgetState();
}

class _ImageBlockWidgetState extends State<ImageBlockWidget> {
  late TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.block.imageCaption ?? '');
  }

  @override
  void didUpdateWidget(covariant ImageBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.imageCaption != widget.block.imageCaption &&
        _captionController.text != (widget.block.imageCaption ?? '')) {
      _captionController.text = widget.block.imageCaption ?? '';
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _saveCaption(String text) {
    final updatedProps = Map<String, dynamic>.from(widget.block.properties);
    updatedProps['caption'] = text.trim();
    widget.onUpdate(widget.block.copyWith(properties: updatedProps));
  }

  Future<void> _replaceImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final savedPath = await StorageService.instance.saveImage(File(picked.path));
      final updatedProps = Map<String, dynamic>.from(widget.block.properties);
      updatedProps['image_path'] = savedPath;
      widget.onUpdate(widget.block.copyWith(properties: updatedProps));
    }
  }

  void _toggleSize() {
    final currentSize = widget.block.properties['size'] as String? ?? 'full';
    String nextSize = 'full';
    if (currentSize == 'full') {
      nextSize = 'large';
    } else if (currentSize == 'large') {
      nextSize = 'medium';
    } else {
      nextSize = 'full';
    }

    final updatedProps = Map<String, dynamic>.from(widget.block.properties);
    updatedProps['size'] = nextSize;
    widget.onUpdate(widget.block.copyWith(properties: updatedProps));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final imagePath = widget.block.imagePath;
    final size = widget.block.properties['size'] as String? ?? 'full';

    double widthFactor = 1.0;
    if (size == 'medium') {
      widthFactor = 0.5;
    } else if (size == 'large') {
      widthFactor = 0.75;
    }

    Widget imageContent;

    if (imagePath == null || imagePath.isEmpty) {
      imageContent = Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: 36,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(height: 8),
              Text(
                'No image selected',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.photo_library, size: 16),
                label: const Text('Add Image'),
                onPressed: _replaceImage,
              ),
            ],
          ),
        ),
      );
    } else {
      final file = File(imagePath);
      final exists = file.existsSync();

      if (!exists) {
        imageContent = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.broken_image, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Image file not found in local storage',
                  style: TextStyle(fontSize: 13, color: Colors.redAccent),
                ),
              ),
              TextButton(
                onPressed: _replaceImage,
                child: const Text('Re-pick'),
              ),
            ],
          ),
        );
      } else {
        imageContent = Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: const Center(child: Icon(Icons.error_outline)),
                ),
              ),
            ),

            // Hover / Action overlay buttons
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                      tooltip: 'View Fullscreen',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => _openFullscreen(context, file),
                    ),
                    IconButton(
                      icon: const Icon(Icons.aspect_ratio, color: Colors.white, size: 18),
                      tooltip: 'Change Size ($size)',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: _toggleSize,
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync, color: Colors.white, size: 18),
                      tooltip: 'Replace Image',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: _replaceImage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      tooltip: 'Delete Image Block',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FractionallySizedBox(
            widthFactor: widthFactor,
            child: imageContent,
          ),

          // Caption Field
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 16.0, right: 16.0),
            child: TextField(
              controller: _captionController,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
                fontStyle: FontStyle.italic,
              ),
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF555555) : const Color(0xFFAAAAAA),
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: _saveCaption,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context, File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }
}
