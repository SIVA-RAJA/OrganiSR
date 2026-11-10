import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/block_model.dart';
import '../models/page_model.dart';
import '../services/database_service.dart';
import 'block_actions_sheet.dart';
import 'icon_helper.dart';
import 'image_block_widget.dart';

class BlockWidget extends StatefulWidget {
  final BlockModel block;
  final int index;
  final bool isFocused;
  final Function(BlockModel updatedBlock) onUpdate;
  final VoidCallback onDelete;
  final Function(BlockModel block)? onEnterPressed;
  final Function(BlockModel block)? onNavigateToPage;
  final Function(BlockType newType)? onTurnInto;
  final VoidCallback? onInsertBelow;
  final VoidCallback? onDuplicate;

  const BlockWidget({
    super.key,
    required this.block,
    required this.index,
    this.isFocused = false,
    required this.onUpdate,
    required this.onDelete,
    this.onEnterPressed,
    this.onNavigateToPage,
    this.onTurnInto,
    this.onInsertBelow,
    this.onDuplicate,
  });

  @override
  State<BlockWidget> createState() => _BlockWidgetState();
}

class _BlockWidgetState extends State<BlockWidget> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.block.content);
    _focusNode = FocusNode();
    if (widget.isFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant BlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.content != widget.block.content &&
        _textController.text != widget.block.content) {
      _textController.text = widget.block.content;
    }
    if (widget.isFocused && !oldWidget.isFocused) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onContentChanged(String text) {
    widget.onUpdate(widget.block.copyWith(content: text));
  }

  void _openActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => BlockActionsSheet(
        block: widget.block,
        onTurnInto: (newType) => widget.onTurnInto?.call(newType),
        onInsertBelow: () => widget.onInsertBelow?.call(),
        onDuplicate: () => widget.onDuplicate?.call(),
        onDelete: widget.onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.block.type == BlockType.image) {
      return ImageBlockWidget(
        block: widget.block,
        onUpdate: widget.onUpdate,
        onDelete: widget.onDelete,
      );
    }

    if (widget.block.type == BlockType.divider) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: InkWell(
          onLongPress: _openActionSheet,
          child: Divider(
            thickness: 1,
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
          ),
        ),
      );
    }

    if (widget.block.type == BlockType.subpage) {
      return _buildSubpageCard(isDark);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onLongPress: _openActionSheet,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? const Color(0xFF222222) : const Color(0xFFF7F7F5))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Block Prefix / Indicator (Todo check, bullet, number, toggle, etc.)
              _buildPrefixWidget(isDark),

              // Content Editor
              Expanded(
                child: _buildTextContent(isDark),
              ),

              // Action button (three dots)
              IconButton(
                icon: const Icon(Icons.more_vert, size: 15),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
                tooltip: 'Block Options',
                onPressed: _openActionSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrefixWidget(bool isDark) {
    switch (widget.block.type) {
      case BlockType.todo:
        return Padding(
          padding: const EdgeInsets.only(top: 2, right: 6),
          child: SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: widget.block.isTodoChecked,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: Colors.white,
              checkColor: Colors.black,
              side: const BorderSide(
                color: Color(0xFF666666),
                width: 1.5,
              ),
              onChanged: (val) {
                final props = Map<String, dynamic>.from(widget.block.properties);
                props['checked'] = val ?? false;
                widget.onUpdate(widget.block.copyWith(properties: props));
              },
            ),
          ),
        );

      case BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(top: 7, right: 8, left: 4),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333),
              shape: BoxShape.circle,
            ),
          ),
        );

      case BlockType.numbered:
        return Padding(
          padding: const EdgeInsets.only(top: 3, right: 6, left: 2),
          child: Text(
            '${widget.index + 1}.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF9B9B9B) : const Color(0xFF787774),
            ),
          ),
        );

      case BlockType.quote:
        return Container(
          width: 3,
          height: 24,
          margin: const EdgeInsets.only(right: 10, left: 2),
          color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF37352F),
        );

      case BlockType.callout:
        return const Padding(
          padding: EdgeInsets.only(top: 6, right: 8, left: 6),
          child: Icon(Icons.info_outline, size: 20, color: Colors.white70),
        );

      default:
        return const SizedBox(width: 2);
    }
  }

  Widget _buildTextContent(bool isDark) {
    TextStyle style = TextStyle(
      fontSize: 15,
      color: isDark ? const Color(0xFFEBEBEB) : const Color(0xFF37352F),
      height: 1.45,
    );
    String hintText = "Type something...";

    switch (widget.block.type) {
      case BlockType.h1:
        style = TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF191919),
          letterSpacing: -0.4,
        );
        hintText = "Heading 1";
        break;
      case BlockType.h2:
        style = TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF191919),
          letterSpacing: -0.3,
        );
        hintText = "Heading 2";
        break;
      case BlockType.h3:
        style = TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF191919),
        );
        hintText = "Heading 3";
        break;
      case BlockType.todo:
        if (widget.block.isTodoChecked) {
          style = style.copyWith(
            decoration: TextDecoration.lineThrough,
            color: isDark ? const Color(0xFF777777) : const Color(0xFF999999),
          );
        }
        hintText = "To-do";
        break;
      case BlockType.quote:
        style = style.copyWith(
          fontStyle: FontStyle.italic,
          color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
        );
        hintText = "Empty quote";
        break;
      case BlockType.callout:
        hintText = "Callout text...";
        break;
      default:
        break;
    }

    if (widget.block.type == BlockType.code) {
      return _buildCodeBlock(isDark);
    }

    // Apply custom text highlight color if set
    if (widget.block.textColor != null && widget.block.textColor!.isNotEmpty) {
      try {
        final hexStr = widget.block.textColor!.replaceFirst('#', '');
        final parsedColor = Color(int.parse('FF$hexStr', radix: 16));
        style = style.copyWith(color: parsedColor);
      } catch (_) {}
    }

    final field = TextField(
      controller: _textController,
      focusNode: _focusNode,
      style: style,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF505050) : const Color(0xFFB0B0B0),
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
      onChanged: _onContentChanged,
      onSubmitted: (_) {
        widget.onEnterPressed?.call(widget.block);
      },
    );

    if (widget.block.type == BlockType.callout) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22252A) : const Color(0xFFF1F1EF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: field,
      );
    }

    return field;
  }

  Widget _buildCodeBlock(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : const Color(0xFFF6F6F4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE2E2E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.block.codeLanguage ?? 'dart',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: EdgeInsets.zero,
                tooltip: 'Copy Code',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _textController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: isDark ? const Color(0xFF56B6C2) : const Color(0xFF206080),
              height: 1.4,
            ),
            maxLines: null,
            decoration: const InputDecoration(
              hintText: '// Paste or write code here...',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: _onContentChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSubpageCard(bool isDark) {
    final targetPageId = widget.block.targetPageId;

    return FutureBuilder<PageModel?>(
      future: targetPageId != null ? DatabaseService.instance.getPage(targetPageId) : null,
      builder: (context, snapshot) {
        final subpage = snapshot.data;
        final icon = subpage?.icon ?? 'page';
        final title = subpage?.title ?? widget.block.content;

        return InkWell(
          onTap: () {
            if (subpage != null) {
              widget.onNavigateToPage?.call(widget.block);
            }
          },
          onLongPress: _openActionSheet,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222222) : const Color(0xFFF7F7F5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
              ),
            ),
            child: Row(
              children: [
                PageIconHelper.renderIcon(icon, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Untitled Sub-page' : title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFEBEBEB) : const Color(0xFF37352F),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFF777777) : const Color(0xFF999999),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
