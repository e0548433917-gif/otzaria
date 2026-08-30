import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria_icons/otzaria_icons.dart';
import 'package:otzaria/utils/file/document_format.dart';

/// אייקון הספר לפי פורמט המסמך — מקור יחיד לכל רשימות הספרייה, תוצאות
/// החיפוש, ההיסטוריה והתצוגות המקדימות.
///
/// הפורמט קודם למחלקת הספר: רשומות היסטוריה ותיקות של ספרי מסמך נשמרו
/// כ-`PdfBook`, ורק הנתיב מגלה שאינן PDF.
IconData bookFormatIcon(Book book) {
  final path = book is FileBook ? book.path : book.filePath;
  // הסיומת קודמת ל-`fileType`: ‏`PdfBook.fileType` הוא ברירת מחדל של הבנאי
  // ולא עובדה שנשמרה, ולכן ספר מסמך שנשמר בהיסטוריה כ-PdfBook היה מוצג
  // כ-PDF לנצח.
  final format =
      (path == null ? null : documentFormatFromExtension(path)) ??
      documentFormatFromFileType(book.fileType);
  if (format == null) {
    return book is PdfBook
        ? OtzariaIcons.book_pdf_24_regular
        : FluentIcons.document_text_24_regular;
  }
  if (format == DocumentFormat.pdf) return OtzariaIcons.book_pdf_24_regular;
  if (format.isWordDocument) return FluentIcons.document_edit_24_regular;
  if (format.isHtmlDocument) return FluentIcons.document_globe_24_regular;
  return FluentIcons.document_text_24_regular;
}
