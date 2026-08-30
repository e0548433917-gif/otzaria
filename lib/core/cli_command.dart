/// נרמול שם פקודת CLI שהגיעה כארגומנט ראשון.
///
/// **חייב להישאר זהה ל-`IsCliInvocation` ב-`windows/runner/main.cpp`.**
/// ה-runner מחליט לפי אותו נרמול אם לדלג על מנעול המופע היחיד ועל ה-splash
/// ולהריץ headless. כל פער בין השניים מייצר מצב שבו ה-runner מדלג על המנעול
/// אבל Dart מעלה אפליקציה מלאה — מופע שני בלי חלון ובלי הגנה על ה-DB.
/// `test/core/cli_command_test.dart` אוכף את השקילות מול קובץ ה-C++.
String normalizeCliCommand(String argument) {
  var command = argument.trim().toLowerCase();
  var start = 0;
  while (start < command.length &&
      (command[start] == '-' || command[start] == '/')) {
    start++;
  }
  return command.substring(start).replaceAll('_', '-');
}
