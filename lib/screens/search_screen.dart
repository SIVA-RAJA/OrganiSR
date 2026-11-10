import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../widgets/icon_helper.dart';
import 'page_view_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final res = await DatabaseService.instance.searchAll(query);
      if (mounted) {
        setState(() {
          _results = res;
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search pages and notes...',
            hintStyle: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _searchController.text.trim().isEmpty
              ? _buildEmptyState('Type keyword to search pages & blocks...', isDark)
              : _results.isEmpty
                  ? _buildEmptyState('No matching pages or blocks found', isDark)
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (context, _) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFEEEEEE),
                      ),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        final isPage = item['result_type'] == 'page';
                        final targetPageId = isPage ? item['id'] as String : item['page_id'] as String;
                        final title = isPage
                            ? (item['title'] as String? ?? 'Untitled')
                            : (item['page_title'] as String? ?? 'Untitled');
                        final icon = isPage
                            ? (item['icon'] as String? ?? 'page')
                            : (item['page_icon'] as String? ?? 'page');
                        final snippet = item['snippet'] as String? ?? '';
                        final updatedAt = DateTime.fromMillisecondsSinceEpoch(
                          item['updated_at'] as int? ?? 0,
                        );

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: PageIconHelper.renderIcon(icon, size: 18),
                          ),
                          title: Text(
                            title.isEmpty ? 'Untitled' : title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (snippet.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    snippet,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              Text(
                                '${isPage ? "Page" : "Block"} • ${DateFormat('yyyy-MM-dd').format(updatedAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PageViewScreen(pageId: targetPageId),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Center(
      child: Text(
        msg,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 14,
        ),
      ),
    );
  }
}
