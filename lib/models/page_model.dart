class PageModel {
  final String id;
  final String? parentId;
  final String title;
  final String icon;
  final String? coverImage;
  final bool isFavorite;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  PageModel({
    required this.id,
    this.parentId,
    required this.title,
    this.icon = 'page',
    this.coverImage,
    this.isFavorite = false,
    this.position = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PageModel copyWith({
    String? id,
    String? parentId,
    bool clearParent = false,
    String? title,
    String? icon,
    String? coverImage,
    bool clearCover = false,
    bool? isFavorite,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PageModel(
      id: id ?? this.id,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      title: title ?? this.title,
      icon: icon ?? this.icon,
      coverImage: clearCover ? null : (coverImage ?? this.coverImage),
      isFavorite: isFavorite ?? this.isFavorite,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'title': title,
      'icon': icon,
      'cover_image': coverImage,
      'is_favorite': isFavorite ? 1 : 0,
      'position': position,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory PageModel.fromMap(Map<String, dynamic> map) {
    return PageModel(
      id: map['id'] as String,
      parentId: map['parent_id'] as String?,
      title: (map['title'] as String?)?.isNotEmpty == true
          ? (map['title'] as String)
          : 'Untitled',
      icon: (map['icon'] as String?)?.isNotEmpty == true
          ? (map['icon'] as String)
          : 'page',
      coverImage: map['cover_image'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
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
