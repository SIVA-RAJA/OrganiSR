import 'package:flutter/material.dart';

class PageIconHelper {
  static const Map<String, IconData> iconMap = {
    'page': Icons.description_outlined,
    'folder': Icons.folder_outlined,
    'calendar': Icons.calendar_today_outlined,
    'journal': Icons.book_outlined,
    'checklist': Icons.check_circle_outline,
    'star': Icons.star_outline,
    'bookmark': Icons.bookmark_outline,
    'idea': Icons.lightbulb_outline,
    'target': Icons.track_changes,
    'flag': Icons.flag_outlined,
    'code': Icons.code,
    'archive': Icons.inventory_2_outlined,
    'time': Icons.schedule_outlined,
    'layers': Icons.layers_outlined,
    'grid': Icons.grid_view_outlined,
    'sparkle': Icons.auto_awesome_outlined,
    'heart': Icons.favorite_border,
    'explore': Icons.explore_outlined,
    'tag': Icons.label_outline,
    'work': Icons.business_center_outlined,
    'school': Icons.school_outlined,
    'fitness': Icons.fitness_center_outlined,
    'music': Icons.music_note_outlined,
    'finance': Icons.account_balance_wallet_outlined,
  };

  static IconData getIconData(String? key, {bool isFolder = false}) {
    if (key == null || key.isEmpty) {
      return isFolder ? Icons.folder_outlined : Icons.description_outlined;
    }

    if (iconMap.containsKey(key)) {
      return iconMap[key]!;
    }

    // Gracefully handle any legacy emojis from old databases
    switch (key) {
      case '📁':
      case '📂':
        return Icons.folder_outlined;
      case '📅':
      case '🗓️':
      case '📆':
        return Icons.calendar_today_outlined;
      case '✍️':
      case '📝':
      case '📖':
        return Icons.book_outlined;
      case '🎯':
        return Icons.track_changes;
      case '💡':
        return Icons.lightbulb_outline;
      case '⭐':
      case '🌟':
        return Icons.star_outline;
      case '🚀':
        return Icons.explore_outlined;
      case '💻':
        return Icons.code;
      case '❤️':
        return Icons.favorite_border;
      case '🏆':
        return Icons.emoji_events_outlined;
      case '📄':
      case '📋':
      default:
        return isFolder ? Icons.folder_outlined : Icons.description_outlined;
    }
  }

  static Widget renderIcon(
    String? key, {
    double size = 18,
    Color? color,
    bool isFolder = false,
  }) {
    return Icon(
      getIconData(key, isFolder: isFolder),
      size: size,
      color: color ?? Colors.white.withValues(alpha: 0.85),
    );
  }

  static Future<String?> showIconPicker(BuildContext context, {String? currentIcon}) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Icon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: iconMap.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      final entry = iconMap.entries.elementAt(index);
                      final isSelected = entry.key == currentIcon;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, entry.key),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : const Color(0xFF202020),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.white : const Color(0xFF303030),
                            ),
                          ),
                          child: Icon(
                            entry.value,
                            size: 22,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
