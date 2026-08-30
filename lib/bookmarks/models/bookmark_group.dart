import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/utils/file/hive_utils.dart';

/// סימניה מרוכזת — אוסף סימניות של כמה ספרים שנשמרו יחד במיקומם הנוכחי,
/// כדי לפתוח את כל הסוגיא מחדש בפעולה אחת.
class BookmarkGroup {
  final String id;
  final String name;
  final List<Bookmark> items;
  final DateTime? createdAt;

  BookmarkGroup({
    String? id,
    required this.name,
    required this.items,
    this.createdAt,
  }) : id = id ?? _generateId();

  static int _idCounter = 0;

  static String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  /// זהויות הספרים בקבוצה — לזיהוי קבוצה דומה בשמירה חוזרת.
  Set<String> get bookIdentities =>
      items.map((item) => bookIdentity(item.book)).toSet();

  /// מדד חפיפה מול [identities]: גודל החיתוך חלקי הקבוצה הגדולה.
  /// ערך ≥ סף פירושו ששתי הקבוצות חולקות את רוב ספריהן זו עם זו.
  double overlapWith(Set<String> identities) {
    final own = bookIdentities;
    if (own.isEmpty || identities.isEmpty) return 0;
    final intersection = own.intersection(identities).length;
    final larger = own.length > identities.length
        ? own.length
        : identities.length;
    return intersection / larger;
  }

  BookmarkGroup copyWith({String? name, List<Bookmark>? items}) {
    return BookmarkGroup(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
      createdAt: createdAt,
    );
  }

  factory BookmarkGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return BookmarkGroup(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      items: rawItems.map((e) => Bookmark.fromJson(castMap(e))).toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
