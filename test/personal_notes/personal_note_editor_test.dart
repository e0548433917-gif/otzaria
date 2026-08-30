import 'dart:convert';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_editor.dart';
import 'package:otzaria/shortcuts/shortcut_helper.dart';

void main() {
  testWidgets('ב-Mac Cmd+Enter שומר, ו-placeholder מציג ⌘', (tester) async {
    ShortcutHelper.isMacForTesting = true;
    addTearDown(() => ShortcutHelper.isMacForTesting = null);

    var saved = 0;
    final focusNode = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: buildPersonalNoteEditorController(
              initialContent: '',
              initialFormat: PersonalNoteContentFormat.plain,
            ),
            focusNode: focusNode,
            scrollController: ScrollController(),
            autofocus: false,
            linkableNotes: const [],
            onSaveShortcut: () => saved++,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    expect(editor.config.placeholder, contains('⌘ + Enter'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(saved, 1);
  });

  testWidgets('כפתור bold פועל גם כ-toggle ומסיר עיצוב קיים', (tester) async {
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: FocusNode(),
            scrollController: ScrollController(),
            autofocus: false,
            linkableNotes: const [],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(FluentIcons.text_bold_24_regular));
    await tester.pump();

    expect(_deltaHasAttribute(controller, quill.Attribute.bold), isTrue);

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    await tester.tap(find.byIcon(FluentIcons.text_bold_24_regular));
    await tester.pump();

    expect(_deltaHasAttribute(controller, quill.Attribute.bold), isFalse);
  });

  testWidgets('כפתור קו חוצה פועל גם כ-toggle ומסיר עיצוב קיים', (
    tester,
  ) async {
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: FocusNode(),
            scrollController: ScrollController(),
            autofocus: false,
            linkableNotes: const [],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(FluentIcons.text_strikethrough_24_regular));
    await tester.pump();

    expect(
      _deltaHasAttribute(controller, quill.Attribute.strikeThrough),
      isTrue,
    );

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    await tester.tap(find.byIcon(FluentIcons.text_strikethrough_24_regular));
    await tester.pump();

    expect(
      _deltaHasAttribute(controller, quill.Attribute.strikeThrough),
      isFalse,
    );
  });

  testWidgets('כפתורי הגדלה/הקטנה משנים את גודל הכתב של הטקסט הנבחר', (
    tester,
  ) async {
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    void selectAll() => controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    selectAll();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: FocusNode(),
            scrollController: ScrollController(),
            autofocus: false,
            linkableNotes: const [],
          ),
        ),
      ),
    );

    // ללא size קיים יוצאים מ-16 (ברירת מחדל) ועולים בצעד של 2.
    await tester.tap(find.byIcon(FluentIcons.font_increase_24_regular));
    await tester.pump();
    expect(_deltaSizeValue(controller), 18.0);

    selectAll();
    await tester.tap(find.byIcon(FluentIcons.font_decrease_24_regular));
    await tester.pump();
    expect(_deltaSizeValue(controller), 16.0);
  });

  testWidgets('הקטנת כתב לא יורדת מתחת לרצפה (12)', (tester) async {
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    void selectAll() => controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    selectAll();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: FocusNode(),
            scrollController: ScrollController(),
            autofocus: false,
            linkableNotes: const [],
          ),
        ),
      ),
    );

    // 16 → 14 → 12 → נשאר 12 (רצפה).
    for (var i = 0; i < 5; i++) {
      selectAll();
      await tester.tap(find.byIcon(FluentIcons.font_decrease_24_regular));
      await tester.pump();
    }
    expect(_deltaSizeValue(controller), 12.0);
  });

  testWidgets('לחיצה על כפתור עיצוב מחזירה פוקוס לעורך', (tester) async {
    // רגרסיה: בעבר לחיצה על IconButton בטולבר גזלה פוקוס מ-QuillEditor
    // ובדסקטופ הפוקוס לא חזר אוטומטית, כי skipRequestKeyboard לבדו לא
    // מספיק כש-_keyboardVisible תמיד true בדסקטופ. הפתרון: _toggleAttribute
    // קורא ידנית editorFocusNode.requestFocus() בסוף.
    final focusNode = FocusNode(debugLabel: 'editor');
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: focusNode,
            scrollController: ScrollController(),
            autofocus: true,
            linkableNotes: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      focusNode.hasFocus,
      isTrue,
      reason: 'autofocus אמור היה לתפוס פוקוס בהתחלה',
    );

    await tester.tap(find.byIcon(FluentIcons.text_bold_24_regular));
    await tester.pump();

    expect(
      focusNode.hasFocus,
      isTrue,
      reason: 'לחיצה על הטולבר חייבת להשאיר את הפוקוס על העורך',
    );
  });

  test('QuillController מוגדר עם enableExternalRichPaste=false', () {
    // רגרסיה: ב-Otzaria העתקה ללוח יוצרת גם HTML מעוצב. כשהדבקנו לעורך
    // הערות, Quill קרא את ה-HTML והעיצוב נדבק לטקסט וגרר את ההמשך
    // לאותו עיצוב. הפתרון: לכבות את ההדבקה החיצונית של rich text.
    final controller = buildPersonalNoteEditorController(
      initialContent: '',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    // ignore: experimental_member_use
    final clipboardConfig = controller.quillController.config.clipboardConfig;
    expect(
      // ignore: experimental_member_use
      clipboardConfig?.enableExternalRichPaste,
      isFalse,
    );

    controller.quillController.dispose();
  });

  testWidgets('QuillEditor מוגדר ללא תפריט סלקציה אוטומטי', (tester) async {
    // רגרסיה: Quill מציגה אוטומטית תפריט copy/paste בסיום גרירה בדסקטופ.
    // בהערות אישיות זה מציק (יש לנו טולבר משלנו וקיצורי מקלדת).
    // הפתרון: enableSelectionToolbar: false ב-QuillEditorConfig.
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום עולם',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: FocusNode(),
            scrollController: ScrollController(),
            autofocus: false,
            linkableNotes: const [],
          ),
        ),
      ),
    );

    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    expect(editor.config.enableSelectionToolbar, isFalse);
  });

  testWidgets('גובה העורך מתכווץ במסך נמוך עם מקלדת פתוחה', (tester) async {
    final controller = buildPersonalNoteEditorController(
      initialContent: '',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    Widget harness({required Size size, required double keyboardInset}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          // Material ולא Scaffold — כמו בדיאלוג ההערה, שבו ה-viewInsets של
          // המקלדת מגיעים לעורך ישירות (Scaffold עם resize בולע אותם).
          child: Material(
            child: SingleChildScrollView(
              child: PersonalNoteEditorBody(
                controller: controller,
                focusNode: FocusNode(),
                scrollController: ScrollController(),
                autofocus: false,
                linkableNotes: const [],
              ),
            ),
          ),
        ),
      );
    }

    double editorHeight() {
      final box = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(quill.QuillEditor),
          matching: find.byType(SizedBox),
        ),
      );
      return box.height!;
    }

    // מסך גבוה בלי מקלדת — הגובה המלא.
    await tester.pumpWidget(
      harness(size: const Size(400, 800), keyboardInset: 0),
    );
    expect(editorHeight(), 220);

    // מסך טלפון עם מקלדת פתוחה — הגובה מתכווץ אך לא מתחת לרצפה.
    await tester.pumpWidget(
      harness(size: const Size(400, 640), keyboardInset: 300),
    );
    expect(editorHeight(), lessThan(220));
    expect(editorHeight(), greaterThanOrEqualTo(120));
  });
}

double? _deltaSizeValue(PersonalNoteEditorController controller) {
  final operations =
      jsonDecode(
            jsonEncode(controller.quillController.document.toDelta().toJson()),
          )
          as List<dynamic>;

  for (final operation in operations) {
    final attributes = (operation as Map<String, dynamic>)['attributes'];
    if (attributes is Map<String, dynamic> && attributes.containsKey('size')) {
      final value = attributes['size'];
      return value is num ? value.toDouble() : double.tryParse('$value');
    }
  }

  return null;
}

bool _deltaHasAttribute(
  PersonalNoteEditorController controller,
  quill.Attribute attribute,
) {
  final operations =
      jsonDecode(
            jsonEncode(controller.quillController.document.toDelta().toJson()),
          )
          as List<dynamic>;

  for (final operation in operations) {
    final attributes = (operation as Map<String, dynamic>)['attributes'];
    if (attributes is Map<String, dynamic> &&
        attributes.containsKey(attribute.key)) {
      return true;
    }
  }

  return false;
}
