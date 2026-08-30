import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/bookmarks/models/bookmark_group.dart';
import 'package:otzaria/data/repository/base_list_repository.dart';
import 'package:otzaria/data/repository/hive_list_repository.dart';

class BookmarkRepository extends BaseListRepository<Bookmark> {
  /// סימניות מרוכזות — נשמרות באותו box תחת מפתח נפרד, כך שהן נכללות
  /// אוטומטית בגיבוי של הסימניות.
  final HiveListRepository<BookmarkGroup> _groupsRepository =
      HiveListRepository<BookmarkGroup>(
        boxName: 'bookmarks',
        key: 'key-bookmark-groups',
        fromJson: (json) => BookmarkGroup.fromJson(json),
        toJson: (group) => group.toJson(),
      );

  BookmarkRepository()
    : super(
        boxName: 'bookmarks',
        key: 'key-bookmarks',
        fromJson: (json) => Bookmark.fromJson(json),
        toJson: (bookmark) => bookmark.toJson(),
      );

  Future<List<Bookmark>> loadBookmarks() async => load();

  Future<void> saveBookmarks(List<Bookmark> bookmarks) async => save(bookmarks);

  Future<void> clearBookmarks() async => clear();

  Future<List<BookmarkGroup>> loadGroups() async => _groupsRepository.load();

  Future<void> saveGroups(List<BookmarkGroup> groups) async =>
      _groupsRepository.save(groups);
}
