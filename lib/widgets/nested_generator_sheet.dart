import 'package:flutter/material.dart';
import '../models/page_model.dart';
import '../services/hierarchy_generator.dart';
import 'icon_helper.dart';

class NestedGeneratorSheet extends StatefulWidget {
  final PageModel? parentPage;
  final VoidCallback onGenerated;

  const NestedGeneratorSheet({
    super.key,
    this.parentPage,
    required this.onGenerated,
  });

  @override
  State<NestedGeneratorSheet> createState() => _NestedGeneratorSheetState();
}

class _NestedGeneratorSheetState extends State<NestedGeneratorSheet> {
  late TextEditingController _titleController;
  String _rootIcon = 'calendar';

  List<HierarchyLevelConfig> _levels = [];

  bool _addLeafNoteHeader = true;
  late TextEditingController _leafHeaderController;
  late TextEditingController _leafStartNumController;

  bool _includeTemplate = false;
  late TextEditingController _templateController;

  bool _isGenerating = false;
  double _progress = 0.0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    final year = DateTime.now().year;

    _titleController = TextEditingController(
      text: widget.parentPage != null ? '${widget.parentPage!.title} Journey' : '10-Year Journey',
    );
    _leafHeaderController = TextEditingController(text: 'DAY {n}');
    _leafStartNumController = TextEditingController(text: '1');
    _templateController = TextEditingController(
      text: '## Focus of the Day\n- [ ] Priority 1\n- [ ] Priority 2\n\n## Daily Reflections\n',
    );

    // Default to 10-Year Journey Preset
    _apply10YearPreset(year);
  }

  void _apply10YearPreset(int startYear) {
    setState(() {
      _titleController.text = widget.parentPage != null
          ? '${widget.parentPage!.title} 10-Year Journey'
          : '10-Year Journey';
      _rootIcon = 'calendar';
      _levels = [
        HierarchyLevelConfig(
          type: LevelType.years,
          startNum: startYear,
          endNum: startYear + 9,
          iconKey: 'calendar',
        ),
        HierarchyLevelConfig(
          type: LevelType.months,
          iconKey: 'folder',
        ),
        HierarchyLevelConfig(
          type: LevelType.days,
          iconKey: 'page',
        ),
      ];
      _addLeafNoteHeader = true;
      _leafHeaderController.text = 'DAY {n}';
      _leafStartNumController.text = '1';
    });
  }

  void _apply1YearPreset(int year) {
    setState(() {
      _titleController.text = widget.parentPage != null
          ? '${widget.parentPage!.title} Journal $year'
          : 'Daily Journal $year';
      _rootIcon = 'journal';
      _levels = [
        HierarchyLevelConfig(
          type: LevelType.months,
          iconKey: 'folder',
        ),
        HierarchyLevelConfig(
          type: LevelType.days,
          iconKey: 'page',
        ),
      ];
      _addLeafNoteHeader = true;
      _leafHeaderController.text = 'DAY {n}';
      _leafStartNumController.text = '1';
    });
  }

  void _applyQuarterlyPreset() {
    setState(() {
      _titleController.text = widget.parentPage != null
          ? '${widget.parentPage!.title} Workspaces'
          : 'Quarterly Workspace';
      _rootIcon = 'layers';
      _levels = [
        HierarchyLevelConfig(
          type: LevelType.customList,
          customNamesRaw: 'Q1, Q2, Q3, Q4',
          iconKey: 'folder',
        ),
        HierarchyLevelConfig(
          type: LevelType.numberRange,
          startNum: 1,
          endNum: 4,
          prefix: 'Sprint',
          iconKey: 'target',
        ),
      ];
      _addLeafNoteHeader = false;
    });
  }

  void _applyCustomPreset() {
    setState(() {
      _titleController.text = 'Custom Workspace';
      _rootIcon = 'folder';
      _levels = [
        HierarchyLevelConfig(
          type: LevelType.numberRange,
          startNum: 1,
          endNum: 5,
          prefix: 'Module',
          iconKey: 'folder',
        ),
        HierarchyLevelConfig(
          type: LevelType.customList,
          customNamesRaw: 'Overview, Tasks, Review',
          iconKey: 'page',
        ),
      ];
      _addLeafNoteHeader = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _leafHeaderController.dispose();
    _leafStartNumController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  void _addLevel() {
    setState(() {
      _levels.add(
        HierarchyLevelConfig(
          type: LevelType.customList,
          customNamesRaw: 'Item 1, Item 2',
          iconKey: 'page',
        ),
      );
    });
  }

  void _removeLevel(int index) {
    if (_levels.length <= 1) return;
    setState(() {
      _levels.removeAt(index);
    });
  }

  Future<void> _startGeneration() async {
    final title = _titleController.text.trim().isEmpty ? 'Structure' : _titleController.text.trim();
    final startNum = int.tryParse(_leafStartNumController.text.trim()) ?? 1;

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _status = 'Preparing pages...';
    });

    try {
      await HierarchyGenerator.instance.generateUnifiedHierarchy(
        rootTitle: title,
        rootIcon: _rootIcon,
        parentPageId: widget.parentPage?.id,
        levels: _levels,
        addLeafNoteHeader: _addLeafNoteHeader,
        leafHeaderFormat: _leafHeaderController.text.trim(),
        leafHeaderStart: startNum,
        commonNoteTemplate: _includeTemplate ? _templateController.text : null,
        onProgress: (p, msg) {
          if (mounted) {
            setState(() {
              _progress = p;
              _status = msg;
            });
          }
        },
      );

      if (!mounted) return;
      widget.onGenerated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Structure "$title" generated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final curYear = DateTime.now().year;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF101010),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Header Drag Handle & Title
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 8),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Generate Nested Pages',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // Root Title & Icon Input
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF282828)),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () async {
                              final picked = await PageIconHelper.showIconPicker(context, currentIcon: _rootIcon);
                              if (picked != null) {
                                setState(() => _rootIcon = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF242424),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: PageIconHelper.renderIcon(_rootIcon, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                hintText: 'Root Structure Title...',
                                hintStyle: TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick 1-Tap Presets
                    const Text(
                      'PRESETS (1-TAP)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF777777),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip('⚡ 10-Year Journey', () => _apply10YearPreset(curYear)),
                          const SizedBox(width: 8),
                          _buildPresetChip('⚡ 1-Year Journal', () => _apply1YearPreset(curYear)),
                          const SizedBox(width: 8),
                          _buildPresetChip('⚡ Quarterly Sprints', _applyQuarterlyPreset),
                          const SizedBox(width: 8),
                          _buildPresetChip('⚡ Custom Multi-Level', _applyCustomPreset),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Visual Hierarchy Levels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'NESTED HIERARCHY LEVELS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF777777),
                          ),
                        ),
                        Text(
                          '${_levels.length} Levels',
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...List.generate(_levels.length, (index) {
                      return _buildLevelCard(index);
                    }),

                    // Add Level Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                      label: const Text('Add Nested Sub-Level', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF333333)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _addLevel,
                    ),

                    const SizedBox(height: 24),

                    // Note Content Customization (Day Numbering & Templates)
                    const Text(
                      'PAGE CONTENT CUSTOMIZATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF777777),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Auto-Numbering in Notes
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF282828)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto-Number in Leaf Page Notes',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Adds sequential DAY 1..3650 header inside the note text',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF777777)),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _addLeafNoteHeader,
                                activeThumbColor: Colors.white,
                                onChanged: (val) => setState(() => _addLeafNoteHeader = val),
                              ),
                            ],
                          ),
                          if (_addLeafNoteHeader) ...[
                            const Divider(height: 18, color: Color(0xFF282828)),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _leafHeaderController,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: InputDecoration(
                                      labelText: 'Header Pattern',
                                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                                      hintText: 'DAY {n}',
                                      filled: true,
                                      fillColor: const Color(0xFF222222),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _leafStartNumController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: InputDecoration(
                                      labelText: 'Start at',
                                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                                      filled: true,
                                      fillColor: const Color(0xFF222222),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Common Note Template
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF282828)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Add Common Note Template',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Switch(
                                value: _includeTemplate,
                                activeThumbColor: Colors.white,
                                onChanged: (val) => setState(() => _includeTemplate = val),
                              ),
                            ],
                          ),
                          if (_includeTemplate) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _templateController,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                hintText: 'Markdown format: # Title, - [ ] Task...',
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: const Color(0xFF222222),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Bottom Generate Action Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF141414),
                  border: Border(top: BorderSide(color: Color(0xFF242424))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _startGeneration,
                    child: const Text(
                      'Generate Structure',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isGenerating)
            Container(
              color: Colors.black87,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      const SizedBox(height: 20),
                      Text(
                        'Generating Structure...',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF202020),
      side: const BorderSide(color: Color(0xFF333333)),
      onPressed: onTap,
    );
  }

  Widget _buildLevelCard(int index) {
    final lvl = _levels[index];
    final isLeaf = index == _levels.length - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LEVEL ${index + 1}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              if (isLeaf) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Leaf Pages',
                    style: TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ),
              ],
              const Spacer(),
              if (_levels.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeLevel(index),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Level Type Selector
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTypeRadio(index, LevelType.years, 'Years'),
              _buildTypeRadio(index, LevelType.months, 'Months'),
              _buildTypeRadio(index, LevelType.days, 'Days (Leap-aware)'),
              _buildTypeRadio(index, LevelType.numberRange, 'Numbered'),
              _buildTypeRadio(index, LevelType.customList, 'Custom List'),
            ],
          ),

          const SizedBox(height: 12),

          // Config Fields based on Type
          if (lvl.type == LevelType.years)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Start Year',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF222222),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: '${lvl.startNum}')
                      ..selection = TextSelection.collapsed(offset: '${lvl.startNum}'.length),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null) lvl.startNum = n;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'End Year',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF222222),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: '${lvl.endNum}')
                      ..selection = TextSelection.collapsed(offset: '${lvl.endNum}'.length),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null) lvl.endNum = n;
                    },
                  ),
                ),
              ],
            )
          else if (lvl.type == LevelType.numberRange)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Prefix (e.g. Sprint)',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF222222),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: lvl.prefix)
                      ..selection = TextSelection.collapsed(offset: lvl.prefix.length),
                    onChanged: (val) => lvl.prefix = val,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'From',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF222222),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: '${lvl.startNum}')
                      ..selection = TextSelection.collapsed(offset: '${lvl.startNum}'.length),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null) lvl.startNum = n;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'To',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF222222),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: '${lvl.endNum}')
                      ..selection = TextSelection.collapsed(offset: '${lvl.endNum}'.length),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null) lvl.endNum = n;
                    },
                  ),
                ),
              ],
            )
          else if (lvl.type == LevelType.customList)
            TextField(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Comma-separated Page Names',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                hintText: 'Q1, Q2, Q3, Q4 or Design, Code, Test',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                isDense: true,
              ),
              controller: TextEditingController(text: lvl.customNamesRaw)
                ..selection = TextSelection.collapsed(offset: lvl.customNamesRaw.length),
              onChanged: (val) => lvl.customNamesRaw = val,
            )
          else if (lvl.type == LevelType.months)
            const Text(
              'Generates 12 calendar months (January to December)',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            )
          else if (lvl.type == LevelType.days)
            const Text(
              'Generates all days in each month with weekday labels. Leap years automatically produce 366 days.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeRadio(int levelIndex, LevelType type, String label) {
    final isSelected = _levels[levelIndex].type == type;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white70)),
      selected: isSelected,
      selectedColor: Colors.white,
      backgroundColor: const Color(0xFF202020),
      side: BorderSide(color: isSelected ? Colors.white : const Color(0xFF333333)),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _levels[levelIndex].type = type;
            if (type == LevelType.years) {
              _levels[levelIndex].iconKey = 'calendar';
            } else if (type == LevelType.months) {
              _levels[levelIndex].iconKey = 'folder';
            } else if (type == LevelType.days) {
              _levels[levelIndex].iconKey = 'page';
            }
          });
        }
      },
    );
  }
}
