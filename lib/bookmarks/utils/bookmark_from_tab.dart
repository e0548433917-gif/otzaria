import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/tabs/models/commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/utils/text/ref_helper.dart';
import 'package:pdfrx/pdfrx.dart';

/// בונה סימניה מטאב קריאה (טקסט/PDF/מפרשים) במיקומו הנוכחי.
///
/// מחזיר null לטאב שאינו ספר. [useStoredPositionFallback] — כשהטאב טרם נטען
/// (רקע), ליפול למיקום השמור בטאב במקום להחזיר null; ההיסטוריה משאירה false
/// כדי לא לרשום טאבים שלא נקראו בפועל.
Future<Bookmark?> bookmarkFromReadingTab(
  OpenedTab tab, {
  String? workspaceName,
  bool useStoredPositionFallback = false,
}) async {
  if (tab is CommentatorsTab) {
    final blocState = tab.bloc.state;
    if (blocState is TextBookLoaded && blocState.visibleIndices.isNotEmpty) {
      final index = blocState.visibleIndices.first;
      String ref = await refFromIndex(
        index,
        Future.value(blocState.tableOfContents),
      );
      ref = addBookTitleToRef(ref, blocState.book.title);
      return Bookmark(
        ref: 'מפרשים | $ref',
        book: blocState.book,
        index: index,
        commentatorsToShow: blocState.activeCommentators,
        workspaceName: workspaceName,
        targetKind: BookmarkTargetKind.commentators,
      );
    }
    if (!useStoredPositionFallback) return null;
    final source = tab.sourceTab;
    String ref = await refFromIndex(source.index, source.book.tableOfContents);
    ref = addBookTitleToRef(ref, source.book.title);
    return Bookmark(
      ref: 'מפרשים | $ref',
      book: source.book,
      index: source.index,
      commentatorsToShow:
          tab.selectedCommentators ?? source.commentators ?? const [],
      workspaceName: workspaceName,
      targetKind: BookmarkTargetKind.commentators,
    );
  }

  if (tab is TextBookTab) {
    final blocState = tab.bloc.state;
    if (blocState is TextBookLoaded && blocState.visibleIndices.isNotEmpty) {
      final index = blocState.visibleIndices.first;
      String ref = await refFromIndex(
        index,
        Future.value(blocState.tableOfContents),
      );
      ref = addBookTitleToRef(ref, blocState.book.title);
      return Bookmark(
        ref: ref,
        book: blocState.book,
        index: index,
        commentatorsToShow: blocState.activeCommentators,
        workspaceName: workspaceName,
      );
    }
    if (!useStoredPositionFallback) return null;
    String ref = await refFromIndex(tab.index, tab.book.tableOfContents);
    ref = addBookTitleToRef(ref, tab.book.title);
    return Bookmark(
      ref: ref,
      book: tab.book,
      index: tab.index,
      commentatorsToShow: tab.commentators ?? const [],
      workspaceName: workspaceName,
    );
  }

  if (tab is PdfBookTab) {
    if (!tab.pdfViewerController.isReady && !useStoredPositionFallback) {
      return null;
    }
    final page = tab.pdfViewerController.isReady
        ? (tab.pdfViewerController.pageNumber ?? tab.pageNumber)
        : tab.pageNumber;

    String ref;
    final outline = tab.outline.value;
    if (outline != null && outline.isNotEmpty) {
      final heading = findHeadingForPage(outline, page);
      ref = heading != null
          ? '${tab.title} $heading — עמוד $page'
          : '${tab.title} עמוד $page';
    } else {
      ref = '${tab.title} עמוד $page';
    }

    return Bookmark(
      ref: ref,
      book: tab.book,
      index: page,
      workspaceName: workspaceName,
    );
  }

  if (tab is PdfCommentatorsTab) {
    final sourceTab = tab.sourceTab;
    final page = sourceTab.pdfViewerController.isReady
        ? (sourceTab.pdfViewerController.pageNumber ?? sourceTab.pageNumber)
        : sourceTab.pageNumber;
    final heading = sourceTab.currentTitle.value.trim();
    final ref = heading.isNotEmpty
        ? 'מפרשים | ${sourceTab.book.title} $heading'
        : 'מפרשים | ${sourceTab.book.title} עמוד $page';

    return Bookmark(
      ref: ref,
      book: sourceTab.book,
      index: page,
      commentatorsToShow: sourceTab.activeCommentators.toList(),
      workspaceName: workspaceName,
      targetKind: BookmarkTargetKind.commentators,
    );
  }

  return null;
}

/// מוצא את הכותרת המתאימה לעמוד מסוים ב-outline של PDF.
String? findHeadingForPage(List<PdfOutlineNode> outline, int page) {
  PdfOutlineNode? bestMatch;

  void searchNodes(List<PdfOutlineNode> nodes) {
    for (final node in nodes) {
      final nodePage = node.dest?.pageNumber;
      if (nodePage != null && nodePage <= page) {
        if (bestMatch == null ||
            nodePage > (bestMatch!.dest?.pageNumber ?? 0)) {
          bestMatch = node;
        }
        if (node.children.isNotEmpty) {
          searchNodes(node.children);
        }
      }
    }
  }

  searchNodes(outline);
  return bestMatch?.title;
}
