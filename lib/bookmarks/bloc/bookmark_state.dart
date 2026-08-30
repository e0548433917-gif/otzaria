import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/bookmarks/models/bookmark_group.dart';

class BookmarkState {
  final List<Bookmark> bookmarks;
  final List<BookmarkGroup> groups;

  BookmarkState({required this.bookmarks, this.groups = const []});

  factory BookmarkState.initial() {
    return BookmarkState(bookmarks: const [], groups: const []);
  }

  BookmarkState copyWith({
    List<Bookmark>? bookmarks,
    List<BookmarkGroup>? groups,
  }) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
      groups: groups ?? this.groups,
    );
  }
}
