import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_state.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/bookmarks/models/bookmark_group.dart';
import 'package:otzaria/bookmarks/repository/bookmark_repository.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/core/messages/notes_messages.dart';
import 'package:otzaria/models/books.dart';

class BookmarkBloc extends Cubit<BookmarkState> {
  final BookmarkRepository _repository;

  BookmarkBloc(this._repository) : super(BookmarkState.initial()) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await _repository.loadBookmarks();
      if (!isClosed) {
        emit(state.copyWith(bookmarks: bookmarks));
      }
    } catch (e, stackTrace) {
      debugPrint('שגיאה בטעינת סימניות: $e\n$stackTrace');
    }
    try {
      final groups = await _repository.loadGroups();
      if (!isClosed) {
        emit(state.copyWith(groups: groups));
      }
    } catch (e, stackTrace) {
      debugPrint('שגיאה בטעינת סימניות מרוכזות: $e\n$stackTrace');
    }
  }

  /// שומר ומדווח שגיאה למשתמש. מחזיר האם השמירה לדיסק הצליחה, כדי שקורא
  /// שצריך תשובה אמיתית (הגשר לתוספים) יוכל להמתין; מסלול ה-UI לא ממתין.
  Future<bool> _persistBookmarks(List<Bookmark> bookmarks) async {
    try {
      await _repository.saveBookmarks(bookmarks);
      return true;
    } catch (e) {
      debugPrint('שגיאה בשמירת סימניות: $e');
      UiSnack.showError(NotesMessages.bookmarkSaveError);
      return false;
    }
  }

  /// מוסיף סימניה וממתין לשמירה לדיסק. מחזיר true רק אם הסימניה גם נוספה
  /// וגם נשמרה — לשימוש הגשר, שאסור לו לדווח הצלחה על כתיבה שנכשלה.
  Future<bool> addBookmarkAndSave({
    required String ref,
    required Book book,
    required int index,
    List<String>? commentatorsToShow,
    BookmarkTargetKind targetKind = BookmarkTargetKind.book,
    String? label,
  }) async {
    final save = _addBookmark(
      ref: ref,
      book: book,
      index: index,
      commentatorsToShow: commentatorsToShow,
      targetKind: targetKind,
      label: label,
    );
    if (save == null) return false;
    return save;
  }

  bool addBookmark({
    required String ref,
    required Book book,
    required int index,
    List<String>? commentatorsToShow,
    BookmarkTargetKind targetKind = BookmarkTargetKind.book,
    String? label,
  }) {
    final save = _addBookmark(
      ref: ref,
      book: book,
      index: index,
      commentatorsToShow: commentatorsToShow,
      targetKind: targetKind,
      label: label,
    );
    if (save == null) return false;
    unawaited(save);
    return true;
  }

  /// מחזיר את Future השמירה, או null אם הסימניה לא נוספה (כפילות).
  Future<bool>? _addBookmark({
    required String ref,
    required Book book,
    required int index,
    List<String>? commentatorsToShow,
    BookmarkTargetKind targetKind = BookmarkTargetKind.book,
    String? label,
  }) {
    final bookmark = Bookmark(
      ref: ref,
      book: book,
      index: index,
      commentatorsToShow: commentatorsToShow ?? [],
      targetKind: targetKind,
      label: label,
      createdAt: DateTime.now(),
    );
    // כפילות נמדדת לפי זיהוי הספר + המיקום (index), כדי לאפשר מספר סימניות
    // באותו ספר במיקומים שונים. ref לבדו לא מספיק - ב-PDF כל הסימניות באותו
    // פרק יקבלו ref זהה (כותרת הפרק), וב-TextBook מספר מיקומים באותו סעיף.
    // משתמשים בזהות חזקה לספר (id/path/category) ולא בכותרת בלבד, כדי
    // ששתי מהדורות שונות עם אותה כותרת לא ייחשבו לאותו ספר.
    final newIdentity = bookIdentity(bookmark.book);
    if (state.bookmarks.any(
      (b) =>
          b.index == bookmark.index &&
          bookIdentity(b.book) == newIdentity &&
          b.targetKind == bookmark.targetKind,
    )) {
      return null;
    }

    final newBookmarks = [...state.bookmarks, bookmark];
    final save = _persistBookmarks(newBookmarks);
    emit(state.copyWith(bookmarks: newBookmarks));
    return save;
  }

  /// מעדכן את טקסט התיאור המוצג של סימניה. [label] ריק מאפס לברירת המחדל
  /// (הצגת המיקום).
  void updateBookmarkLabel(int index, String? label) {
    if (index < 0 || index >= state.bookmarks.length) return;
    final trimmed = label?.trim();
    final hasLabel = trimmed != null && trimmed.isNotEmpty;
    final updated = [...state.bookmarks];
    updated[index] = updated[index].copyWith(
      label: hasLabel ? trimmed : null,
      clearLabel: !hasLabel,
    );
    unawaited(_persistBookmarks(updated));
    emit(state.copyWith(bookmarks: updated));
  }

  /// מחזיר false אם [index] מחוץ לתחום ולכן לא נמחקה סימניה.
  bool removeBookmark(int index) {
    final save = _removeBookmark(index);
    if (save == null) return false;
    unawaited(save);
    return true;
  }

  /// מסיר סימניה וממתין לשמירה לדיסק — המסלול של הגשר לתוספים.
  Future<bool> removeBookmarkAndSave(int index) async {
    final save = _removeBookmark(index);
    if (save == null) return false;
    return save;
  }

  Future<bool>? _removeBookmark(int index) {
    if (index < 0 || index >= state.bookmarks.length) return null;
    final newBookmarks = [...state.bookmarks]..removeAt(index);
    final save = _persistBookmarks(newBookmarks);
    emit(state.copyWith(bookmarks: newBookmarks));
    return save;
  }

  void clearBookmarks() {
    _repository.clearBookmarks().catchError((Object e) {
      debugPrint('שגיאה במחיקת סימניות: $e');
      UiSnack.showError(NotesMessages.bookmarkClearError);
    });
    emit(state.copyWith(bookmarks: []));
  }

  /// סף החפיפה לזיהוי "אותה קבוצה" בשמירה חוזרת — רוב הספרים משותפים
  /// (החיתוך ביחס לקבוצה הגדולה מבין השתיים).
  static const double _groupOverlapThreshold = 0.6;

  /// מחזיר את הקבוצה הקיימת הדומה ביותר לקבוצת ספרים בעלת הזהויות
  /// [identities], או null אם אף קבוצה אינה חופפת ברוב ספריה.
  BookmarkGroup? findSimilarGroup(Set<String> identities) {
    BookmarkGroup? best;
    var bestOverlap = 0.0;
    for (final group in state.groups) {
      final overlap = group.overlapWith(identities);
      if (overlap >= _groupOverlapThreshold && overlap > bestOverlap) {
        best = group;
        bestOverlap = overlap;
      }
    }
    return best;
  }

  void _persistGroups(List<BookmarkGroup> groups) {
    unawaited(
      _repository.saveGroups(groups).catchError((Object e) {
        debugPrint('שגיאה בשמירת סימניות מרוכזות: $e');
        UiSnack.showError(NotesMessages.bookmarkSaveError);
      }),
    );
  }

  void addGroup(BookmarkGroup group) {
    final newGroups = [...state.groups, group];
    _persistGroups(newGroups);
    emit(state.copyWith(groups: newGroups));
  }

  /// מחליף קבוצה קיימת בתוכן חדש תוך שמירת המזהה שלה.
  /// מחזיר false אם [id] לא נמצא.
  bool replaceGroup(String id, BookmarkGroup replacement) {
    final index = state.groups.indexWhere((g) => g.id == id);
    if (index < 0) return false;
    final newGroups = [...state.groups];
    newGroups[index] = newGroups[index].copyWith(
      name: replacement.name,
      items: replacement.items,
    );
    _persistGroups(newGroups);
    emit(state.copyWith(groups: newGroups));
    return true;
  }

  bool removeGroup(String id) {
    final newGroups = state.groups.where((g) => g.id != id).toList();
    if (newGroups.length == state.groups.length) return false;
    _persistGroups(newGroups);
    emit(state.copyWith(groups: newGroups));
    return true;
  }

  void renameGroup(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = state.groups.indexWhere((g) => g.id == id);
    if (index < 0) return;
    final newGroups = [...state.groups];
    newGroups[index] = newGroups[index].copyWith(name: trimmed);
    _persistGroups(newGroups);
    emit(state.copyWith(groups: newGroups));
  }

  /// מוחק את כל הסימניות של ספר ספציפי (לפי זהות חזקה - id/path/category),
  /// משאיר סימניות של ספרים אחרים על כנן.
  ///
  /// מחזיר true אם נמחקה לפחות סימניה אחת, false אם לא היו סימניות תואמות.
  /// מאפשר ל-UI להימנע מהודעת הצלחה מטעה כשלא בוצעה מחיקה בפועל.
  bool clearBookmarksForBook(Book book) {
    final targetIdentity = bookIdentity(book);
    final remaining = state.bookmarks
        .where((b) => bookIdentity(b.book) != targetIdentity)
        .toList();
    if (remaining.length == state.bookmarks.length) return false;
    unawaited(_persistBookmarks(remaining));
    emit(state.copyWith(bookmarks: remaining));
    return true;
  }
}
