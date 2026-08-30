import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/text/html_link_handler.dart';

Library _libraryWith(List<Book> books) => Library(
  categories: [
    Category(
      title: 'קטגוריה',
      description: '',
      shortDescription: '',
      order: 1,
      subCategories: [],
      books: books,
      parent: null,
    ),
  ],
);

void main() {
  group('יעד של קישור book://', () {
    test('ספר טקסט רגיל נמצא', () {
      final library = _libraryWith([
        TextBook(title: 'ברכות', filePath: 'C:/ספרים/ברכות.txt'),
      ]);
      expect(
        HtmlLinkHandler.resolveBookLinkTarget(library, 'ברכות')?.title,
        'ברכות',
      );
    });

    // ‏`findBookByTitle` משווה `runtimeType` ולא `is`, ולכן בלי העטיפה
    // ב-`toTextBook()` כל קישור `book://` אל ספר-מסמך היה מת — וב-HTML זו
    // הדרך המתועדת לקשר בין ספרים.
    for (final entry in const {
      'html': 'ספר.html',
      'htm': 'ספר.htm',
      'docx': 'ספר.docx',
      'epub': 'ספר.epub',
      'odt': 'ספר.odt',
    }.entries) {
      test('ספר-מסמך מסוג ${entry.key} נפתר לספר טקסט', () {
        final book = buildBookForFileType(
          fileType: entry.key,
          title: 'ספר',
          path: 'C:/ספרים/${entry.value}',
          filePath: 'C:/ספרים/${entry.value}',
          categoryId: 7,
        );
        expect(book, isA<ConvertibleDocumentBook>(), reason: entry.key);

        final resolved = HtmlLinkHandler.resolveBookLinkTarget(
          _libraryWith([book]),
          'ספר',
        );
        expect(resolved, isNotNull, reason: entry.key);
        // שדות הזהות נשמרים — בלעדיהם `getBookText` אינו מאתר את הספר.
        expect(resolved!.fileType, entry.key);
        expect(resolved.filePath, 'C:/ספרים/${entry.value}');
        expect(resolved.categoryId, 7);
      });
    }

    test('ספר PDF אינו יעד לקישור טקסט', () {
      final library = _libraryWith([
        PdfBook(title: 'ספר', path: 'C:/ספרים/ספר.pdf'),
      ]);
      expect(HtmlLinkHandler.resolveBookLinkTarget(library, 'ספר'), isNull);
    });

    test('ספר שאינו קיים מחזיר null', () {
      expect(
        HtmlLinkHandler.resolveBookLinkTarget(_libraryWith([]), 'אין'),
        isNull,
      );
    });
  });

  group('HtmlLinkHandler Markdown anchors', () {
    test('משווה slug של Markdown לכותרת עם פיסוק ורווחים', () {
      expect(
        HtmlLinkHandler.isHeaderMatch('0. מפה מהירה', '0-מפה-מהירה'),
        isTrue,
      );
      expect(
        HtmlLinkHandler.isHeaderMatch('פרק: מבוא כללי', 'פרק-מבוא-כללי'),
        isTrue,
      );
    });

    test('מוצא עוגן בכותרת מקוננת', () {
      final root = TocEntry(text: 'ראשי', index: 0, level: 1);
      root.children.add(
        TocEntry(
          text: '0. מפה מהירה',
          index: 7,
          level: 2,
          parent: root,
        ),
      );

      expect(
        HtmlLinkHandler.findHeaderIndexInToc([root], '0-מפה-מהירה'),
        7,
      );
    });

    test('אינו מחזיר התאמת substring לכותרת קצרה', () {
      expect(HtmlLinkHandler.isHeaderMatch('פרק ב', 'ב'), isFalse);
    });

    test('מוצא עוגן יעד מפורש שהוגדר ב-<a name>', () {
      expect(
        HtmlLinkHandler.findAnchorIndex(
          const [
            '<p>פתיחה</p>',
            '<a name="3a-סוגי-קשר"></a>',
            '<h2 id="3א-סוגי-קשר-connection-type">3א. סוגי קשר</h2>',
          ],
          '3a-סוגי-קשר',
        ),
        1,
      );
    });

    test('עוגן יעד שאינו קיים אינו מוחזר', () {
      expect(
        HtmlLinkHandler.findAnchorIndex(
          const ['<a name="אחר"></a>'],
          'לא-קיים',
        ),
        isNull,
      );
    });

    test('מעדיף id מפורש של כותרת גם כשהטקסט שונה', () {
      expect(
        HtmlLinkHandler.findAnchorIndex(
          const ['<p>פתיחה</p>', '<h2 id="2-ספירת-db">נוסח אחר</h2>'],
          '2-ספירת-db',
        ),
        1,
      );
    });
  });
}
