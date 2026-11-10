import 'dart:convert';

enum BlockType {
  text,
  h1,
  h2,
  h3,
  h4,
  bullet,
  numbered,
  todo,
  toggle,
  quote,
  callout,
  divider,
  code,
  image,
  subpage;

  static BlockType fromString(String type) {
    return BlockType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => BlockType.text,
    );
  }
}

class BlockModel {
  final String id;
  final String pageId;
  final BlockType type;
  final String content;
  final Map<String, dynamic> properties;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  BlockModel({
    required this.id,
    required this.pageId,
    required this.type,
    this.content = '',
    Map<String, dynamic>? properties,
    this.position = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : properties = properties ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isTodoChecked => properties['checked'] == true;
  String? get imagePath => properties['image_path'] as String?;
  String? get imageCaption => properties['caption'] as String?;
  String? get calloutIcon => properties['icon'] as String? ?? 'info';
  String? get codeLanguage => properties['language'] as String? ?? 'dart';
  String? get targetPageId => properties['page_id'] as String?;
  String? get blockColor => properties['color'] as String?;
  String? get textColor => properties['text_color'] as String?;
  String? get textBgColor => properties['text_bg'] as String?;
  bool get isToggleExpanded => properties['expanded'] != false; // default true

  BlockModel copyWith({
    String? id,
    String? pageId,
    BlockType? type,
    String? content,
    Map<String, dynamic>? properties,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BlockModel(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      type: type ?? this.type,
      content: content ?? this.content,
      properties: properties ?? Map<String, dynamic>.from(this.properties),
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'page_id': pageId,
      'type': type.name,
      'content': content,
      'properties': jsonEncode(properties),
      'position': position,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory BlockModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> props = {};
    if (map['properties'] != null) {
      try {
        final decoded = jsonDecode(map['properties'] as String);
        if (decoded is Map<String, dynamic>) {
          props = decoded;
        }
      } catch (_) {}
    }

    return BlockModel(
      id: map['id'] as String,
      pageId: map['page_id'] as String,
      type: BlockType.fromString(map['type'] as String? ?? 'text'),
      content: map['content'] as String? ?? '',
      properties: props,
      position: map['position'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
