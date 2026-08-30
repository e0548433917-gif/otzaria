import 'package:flutter/widgets.dart';
import 'package:otzaria/plugins/utils/fluent_icon_resolver.dart';
import 'package:otzaria_icons/otzaria_icons.dart';

/// תחילית שכופה פתרון מספריית האייקונים של אוצריא בלבד.
const String kOtzariaIconPrefix = 'otzaria:';

/// תחילית שכופה פתרון מ-FluentUI בלבד.
const String kFluentIconPrefix = 'fluent:';

/// פותר שם אייקון שהצהיר עליו תוסף ל-[IconData].
///
/// בשם שקיים בשתי הספריות אוצריא מנצחת, כדי שאייקון של תוסף ייראה זהה
/// לאייקון המקביל בממשק אוצריא. תחילית [kOtzariaIconPrefix] או
/// [kFluentIconPrefix] כופה ספרייה אחת בלבד, בלי נפילה לשנייה.
/// מחזיר null לשם שאינו מוכר.
IconData? pluginIconFromName(String? name) {
  if (name == null) return null;
  if (name.startsWith(kOtzariaIconPrefix)) {
    return OtzariaIcons.allIcons[name.substring(kOtzariaIconPrefix.length)];
  }
  if (name.startsWith(kFluentIconPrefix)) {
    return fluentIconFromName(name.substring(kFluentIconPrefix.length));
  }
  return OtzariaIcons.allIcons[name] ?? fluentIconFromName(name);
}
