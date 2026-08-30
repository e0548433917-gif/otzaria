import 'dart:math' as math;

import 'package:flutter/material.dart';

/// תוכן ממורכז שאינו נחתך בחלון נמוך.
///
/// מסכי מצב (ריק/שגיאה/הגדרה) בנויים מאייקון גדול, טקסטים וכפתור פעולה —
/// יחד כ-250–450px. `Center` + `Column` בלבד חותך אותם בטלפון לרוחב, במסך
/// מפוצל ובחלון דסקטופ נמוך, והכפתור יוצא מחוץ למסך ואינו לחיץ.
///
/// כאן התוכן ממורכז כשיש מקום, וגליל כשאין.
class CenteredScrollableState extends StatelessWidget {
  final Widget child;

  /// שוליים סביב התוכן, בתוך אזור הגלילה.
  final EdgeInsetsGeometry padding;

  const CenteredScrollableState({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          // minHeight שומר על המרכוז האנכי כשהתוכן נמוך מהאזור הפנוי.
          // clamp: אזור נמוך מהריפוד עצמו היה מייצר minHeight שלילי וזורק.
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite
                ? math.max(0.0, constraints.maxHeight - padding.vertical)
                : 0,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
