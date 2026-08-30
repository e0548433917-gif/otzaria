import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/view/pane_drop_target.dart';

/// עובי קו החיווי שמסמן היכן הכרטיסיה הנגררת תיכנס.
const double _kInsertLineWidth = 3;

/// כמה זמן להתעכב מעל כרטיסיה בזמן גרירה עד שהיא נפתחת.
///
/// קצר מדי — כל מעבר מעל כרטיסיה בדרך לאזור הקריאה היה מחליף ספר; ארוך מדי
/// והמחווה מרגישה תקועה.
const Duration kTabSpringOpenDelay = Duration(milliseconds: 400);

/// שקיפות הכרטיסיה במקומה המקורי בזמן שגוררים אותה.
const double _kDraggingTabOpacity = 0.35;

/// עומק אזור הקצה שגרירה בתוכו גוללת את הרצועה.
const double _kAutoScrollEdge = 40;

/// קצב הגלילה האוטומטית — פיקסלים לכל פעימה (פעימה לכל פריים בקירוב).
const double _kAutoScrollStep = 8;

const Duration _kAutoScrollTick = Duration(milliseconds: 16);

/// רצועת כרטיסיות העיון.
///
/// כל כרטיסיה היא [Draggable] של הטאב עצמו, ולכן אותה מחווה משרתת שני
/// יעדים: שחרור בתוך הרצועה מסדר מחדש, ושחרור מעל אזור הקריאה מפצל אותו
/// לשתיים — כי אותו מטען מתקבל גם ב-[PaneDropTarget] שבמסך הקריאה.
///
/// זו הסיבה שהרצועה אינה [ReorderableListView]: הוא בולע את המחווה ואין לו
/// דרך לדעת שהמצביע יצא מגבולותיו.
class ReadingTabStrip extends StatefulWidget {
  /// הכרטיסיות בסדר התצוגה.
  final List<OpenedTab> tabs;

  /// מידת כל כרטיסיה לאורך ציר הרצועה — רוחב באופקית, גובה באנכית.
  final List<double> widths;

  /// ציר הרצועה. באנכית אין היפוך RTL: הכרטיסיה הראשונה תמיד למעלה.
  final Axis axis;

  /// רוחב הכרטיסיה הצפה בגרירה כשהציר אנכי; באופקית הרוחב נלקח מ-[widths].
  final double? crossExtent;

  /// האם הרצועה עצמה נגללת. ברצועה האופקית הרוחבים מחושבים כך שהכל נכנס.
  final bool scrollable;

  /// במגע נדרשת לחיצה ארוכה, כדי שהחלקה או גלילה לא יגררו כרטיסיה בטעות.
  final bool requireLongPressToDrag;

  /// בונה את תוכן הכרטיסיה. התוצאה נעטפת ב-[Draggable] ולכן חייבת לכלול את
  /// סמן ה-hit-test שהרצועה החיצונית מסתמכת עליו.
  final Widget Function(OpenedTab tab, int index, double width) tabBuilder;

  /// נקרא עם היעד בקונבנציית הסרה-ואז-הכנסה, כמצופה ב-`MoveTab`.
  final void Function(OpenedTab tab, int newIndex) onReorder;

  /// האם לקבל כרטיסיה נגררת שאינה ברצועה — חלונית של טאב מפוצל שנגררת
  /// חזרה לשורת הכרטיסיות.
  final bool Function(OpenedTab tab)? acceptsExternal;

  /// נקרא בשחרור כרטיסיה חיצונית, עם מיקום הכנסה בטווח `0..tabs.length`.
  final void Function(OpenedTab tab, int insertIndex)? onExternalDrop;

  /// נקרא כשמתחילה גרירת כרטיסיה.
  final VoidCallback? onDragStarted;

  /// נקרא כשגרירה משתהה מעל כרטיסיה — היא נפתחת, וכך אפשר להמשיך ולשחרר
  /// את הנגררת לצדה באזור הקריאה בלי לוותר על הגרירה.
  final void Function(OpenedTab tab)? onSpringOpen;

  const ReadingTabStrip({
    super.key,
    required this.tabs,
    required this.widths,
    required this.tabBuilder,
    required this.onReorder,
    this.acceptsExternal,
    this.onExternalDrop,
    this.onDragStarted,
    this.onSpringOpen,
    this.requireLongPressToDrag = false,
    this.axis = Axis.horizontal,
    this.crossExtent,
    this.scrollable = false,
  });

  bool get isVertical => axis == Axis.vertical;

  @override
  State<ReadingTabStrip> createState() => _ReadingTabStripState();
}

class _ReadingTabStripState extends State<ReadingTabStrip> {
  late _TabStripGeometry _geometry;

  /// מיקום ההכנסה הנוכחי בטווח `0..tabs.length`, או `null` כשאין גרירה מעל.
  int? _insertIndex;

  /// הכרטיסיה שהגרירה משתהה מעליה, והשעון שיפתח אותה.
  OpenedTab? _springTarget;
  Timer? _springTimer;

  final ScrollController _scrollController = ScrollController();

  /// גלילת הקצה: הכיוון (1- למעלה/להתחלה, 1 למטה/לסוף), השעון שמניע אותה,
  /// והגרירה האחרונה שנמדדה — כדי לעדכן את מיקום ההכנסה גם כשהסמן עומד.
  double _autoScrollDirection = 0;
  Timer? _autoScrollTimer;
  OpenedTab? _autoScrollTab;
  Offset? _autoScrollOffset;

  @override
  void initState() {
    super.initState();
    _geometry = _TabStripGeometry.fromWidths(widget.widths);
  }

  @override
  void didUpdateWidget(covariant ReadingTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_geometry.widths, widget.widths)) {
      _geometry = _TabStripGeometry.fromWidths(widget.widths);
    }
  }

  @override
  void dispose() {
    _springTimer?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// מזניק או עוצר את גלילת הקצה לפי מיקום הסמן ברצועה.
  void _updateAutoScroll(OpenedTab dragged, Offset globalOffset) {
    if (!widget.scrollable) return;

    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _stopAutoScroll();

    final local = box.globalToLocal(globalOffset);
    final main = widget.isVertical ? local.dy : local.dx;
    final extent = widget.isVertical ? box.size.height : box.size.width;

    // רחוק מחוץ לרצועה הגרירה כבר מכוונת לאזור הקריאה, ולא לסידור מחדש.
    if (main < -_kAutoScrollEdge || main > extent + _kAutoScrollEdge) {
      return _stopAutoScroll();
    }

    var direction = 0.0;
    if (main < _kAutoScrollEdge) {
      direction = -1;
    } else if (main > extent - _kAutoScrollEdge) {
      direction = 1;
    }
    // ב-RTL אופקי הגלילה מתקדמת שמאלה, ולכן קצה המסך ההפוך מגליל קדימה.
    if (_flipsForRtl) direction = -direction;

    if (direction == 0) return _stopAutoScroll();

    _autoScrollDirection = direction;
    _autoScrollTab = dragged;
    _autoScrollOffset = globalOffset;
    _autoScrollTimer ??= Timer.periodic(_kAutoScrollTick, _onAutoScrollTick);
  }

  void _onAutoScrollTick(Timer timer) {
    if (!_scrollController.hasClients) return _stopAutoScroll();

    final position = _scrollController.position;
    final target = (position.pixels + _autoScrollDirection * _kAutoScrollStep)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return _stopAutoScroll();

    position.jumpTo(target);
    // הרצועה זזה תחת סמן שעומד במקומו, ולכן מיקום ההכנסה נמדד מחדש.
    final tab = _autoScrollTab;
    final offset = _autoScrollOffset;
    if (tab != null && offset != null) _updateDragPosition(tab, offset);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollDirection = 0;
    _autoScrollTab = null;
    _autoScrollOffset = null;
  }

  /// שורת הכרטיסיות עצמה. הרצועה נמתחת על כל הרוחב הפנוי, ולכן מדידה מול
  /// גבולותיה הייתה מוסיפה את השטח הריק — וב-RTL, שבו הכרטיסיות צמודות
  /// לימין, כל ההפרש נכנס לחישוב ומיקום ההכנסה יצא תמיד 0.
  final GlobalKey _contentKey = GlobalKey();

  /// מכל הגלילה עצמו — גבולותיו הם אזורי הקצה שגלילה אוטומטית נמדדת מולם,
  /// בשונה מ-[_contentKey] שגדל עם הכרטיסיות וזז עם הגלילה.
  final GlobalKey _viewportKey = GlobalKey();

  /// ב-RTL הכרטיסיה הראשונה יושבת בימין, ולכן המרחק נמדד מהקצה הימני. בציר
  /// אנכי אין היפוך: הכרטיסיה הראשונה למעלה בשתי הכיווניות.
  bool get _flipsForRtl =>
      !widget.isVertical && Directionality.of(context) == TextDirection.rtl;

  /// מיקום ההכנסה שאליו מצביע [localMain] (מיקום מקומי לאורך ציר הרצועה).
  ///
  /// ההשוואה היא לאמצע כל כרטיסיה — כך היעד מתחלף בדיוק כשחוצים אותה,
  /// והמידות אינן חייבות להיות אחידות.
  int _insertIndexFor(double localMain) {
    final total = _geometry.totalWidth;
    final flow = _flipsForRtl ? total - localMain : localMain;
    return _geometry.insertIndexAt(flow);
  }

  /// קצה ההתחלה של קו החיווי בתוך רצועת הכרטיסיות, מוגבל לגבולותיה — קו
  /// שחורג מהן מפעיל חיתוך ב-Stack וקוצץ את קצות הכרטיסיה הנבחרת.
  double _insertLineOffset(int index) {
    final edge = _geometry.edgeAt(index);
    final total = _geometry.totalWidth;
    final visualEdge = _flipsForRtl ? total - edge : edge;
    final maxOffset = total - _kInsertLineWidth;
    if (maxOffset <= 0) return 0;
    return (visualEdge - _kInsertLineWidth / 2).clamp(0.0, maxOffset);
  }

  /// הכרטיסיה שמתחת ל-[localMain], או `null` מחוץ לרצועה.
  ///
  /// שונה מ-[_insertIndexFor], שמחזיר גבול בין כרטיסיות ולא כרטיסיה.
  OpenedTab? _tabAt(double localMain) {
    final total = _geometry.totalWidth;
    final flow = _flipsForRtl ? total - localMain : localMain;
    final index = _geometry.tabIndexAt(flow);
    return index == null ? null : widget.tabs[index];
  }

  /// מזניק את שעון הפתיחה כשהגרירה עברה לכרטיסיה אחרת, ומאפס אותו כשהיא
  /// יצאה מהשורה. השהייה על אותה כרטיסיה ממשיכה את השעון הקיים.
  void _updateSpringTarget(OpenedTab dragged, OpenedTab? hovered) {
    if (hovered == null || identical(hovered, dragged)) {
      _cancelSpring();
      return;
    }
    if (identical(hovered, _springTarget)) return;

    _cancelSpring();
    _springTarget = hovered;
    _springTimer = Timer(kTabSpringOpenDelay, () {
      _springTimer = null;
      widget.onSpringOpen?.call(hovered);
    });
  }

  void _cancelSpring() {
    _springTimer?.cancel();
    _springTimer = null;
    _springTarget = null;
  }

  void _updateDragPosition(OpenedTab dragged, Offset globalOffset) {
    _updateAutoScroll(dragged, globalOffset);

    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final local = box.globalToLocal(globalOffset);
    final localMain = widget.isVertical ? local.dy : local.dx;
    // פתיחת כרטיסיה בהשתהות הייתה מחליפה את הטאב המוצג — ובגרירה חיצונית
    // (מחלונית מפוצלת) מפרקת את מקור הגרירה עצמו באמצע המחווה.
    if (_acceptsReorder(dragged)) {
      _updateSpringTarget(dragged, _tabAt(localMain));
    }

    // setState רק כשהיעד באמת זז: onMove יורה בכל תזוזת מצביע.
    final next = _insertIndexFor(localMain);
    if (next != _insertIndex) setState(() => _insertIndex = next);
  }

  /// כרטיסיה שנמצאת ברצועה — לסידור מחדש.
  bool _acceptsReorder(OpenedTab tab) => widget.tabs.contains(tab);

  bool _accepts(OpenedTab tab) =>
      _acceptsReorder(tab) ||
      (widget.onExternalDrop != null &&
          (widget.acceptsExternal?.call(tab) ?? false));

  void _completeReorder(OpenedTab tab) {
    final insertIndex = _insertIndex;
    _cancelSpring();
    _stopAutoScroll();
    setState(() => _insertIndex = null);
    if (insertIndex == null) return;

    final oldIndex = widget.tabs.indexOf(tab);
    if (oldIndex == -1) {
      // כרטיסיה חיצונית נכנסת במיקום ההכנסה כמות שהוא — אין מה להסיר.
      widget.onExternalDrop?.call(tab, insertIndex);
      return;
    }

    // תיאום לקונבנציית הסרה-ואז-הכנסה: אחרי הסרת הכרטיסיה כל מיקום שאחריה
    // נסוג באחד. בלי זה גרירה ימינה הייתה נוחתת כרטיסיה אחת רחוק מדי.
    final target = insertIndex > oldIndex ? insertIndex - 1 : insertIndex;
    if (target == oldIndex) return;

    widget.onReorder(tab, target);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<OpenedTab>(
      onWillAcceptWithDetails: (details) {
        if (!_accepts(details.data)) return false;
        _updateDragPosition(details.data, details.offset);
        return true;
      },
      onMove: (details) {
        if (_accepts(details.data)) {
          _updateDragPosition(details.data, details.offset);
        }
      },
      onLeave: (_) {
        _cancelSpring();
        _stopAutoScroll();
        if (_insertIndex != null) setState(() => _insertIndex = null);
      },
      onAcceptWithDetails: (details) => _completeReorder(details.data),
      builder: (context, candidate, rejected) {
        // הרצועה נמתחת על כל הרוחב הפנוי ולא מתכווצת לרוחב הכרטיסיות: השטח
        // שנותר הוא "האזור הריק" שגרירת חלון ולחיצה כפולה למסך מלא מסתמכות
        // על קיומו.
        final isVertical = widget.isVertical;
        return SizedBox(
          width: isVertical ? null : double.infinity,
          height: isVertical ? double.infinity : null,
          // ברצועה האופקית הגלילה מנוטרלת: הרוחבים מחושבים כך שכל הכרטיסיות
          // ייכנסו, אבל בפריים הראשון — לפני שאזור הכרטיסיות נמדד — הם לפי
          // רוחב המסך. בלי מכל שגולש בשקט אותו פריים היה זורק overflow.
          child: SingleChildScrollView(
            key: _viewportKey,
            controller: _scrollController,
            scrollDirection: widget.axis,
            physics: widget.scrollable
                ? null
                : const NeverScrollableScrollPhysics(),
            // קו החיווי יושב באותו Stack עם הרצועה, ולכן באותה מערכת
            // קואורדינטות שבה נמדד מיקום ההכנסה.
            child: Stack(
              children: [
                Flex(
                  key: _contentKey,
                  direction: widget.axis,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.tabs.length; i++)
                      _DraggableTab(
                        key: ObjectKey(widget.tabs[i]),
                        tab: widget.tabs[i],
                        axis: widget.axis,
                        extent: widget.widths[i],
                        crossExtent: widget.crossExtent,
                        requireLongPress: widget.requireLongPressToDrag,
                        onDragStarted: widget.onDragStarted,
                        // גרירה שהסתיימה מחוץ לרצועה אינה מפעילה onLeave,
                        // ולכן קו החיווי מנוקה גם כאן.
                        onDragFinished: () {
                          _cancelSpring();
                          _stopAutoScroll();
                          if (_insertIndex != null) {
                            setState(() => _insertIndex = null);
                          }
                        },
                        child: widget.tabBuilder(
                          widget.tabs[i],
                          i,
                          widget.widths[i],
                        ),
                      ),
                  ],
                ),
                if (_insertIndex != null)
                  _InsertIndicator(
                    axis: widget.axis,
                    offset: _insertLineOffset(_insertIndex!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// גבולות מצטברים של הכרטיסיות: נבנים רק כשמערך הרוחבים מתעדכן, וכל
/// תזוזת מצביע מחפשת בהם במקום לסרוק את הכרטיסיות שוב.
class _TabStripGeometry {
  final List<double> widths;
  final List<double> _edges;
  final List<double> _midpoints;

  const _TabStripGeometry._(this.widths, this._edges, this._midpoints);

  factory _TabStripGeometry.fromWidths(List<double> widths) {
    final edges = <double>[0];
    final midpoints = <double>[];
    var total = 0.0;
    for (final width in widths) {
      midpoints.add(total + width / 2);
      total += width;
      edges.add(total);
    }
    return _TabStripGeometry._(List.unmodifiable(widths), edges, midpoints);
  }

  double get totalWidth => _edges.last;

  double edgeAt(int index) => _edges[index.clamp(0, _edges.length - 1)];

  int insertIndexAt(double flowX) {
    var lower = 0;
    var upper = _midpoints.length;
    while (lower < upper) {
      final middle = (lower + upper) ~/ 2;
      if (flowX < _midpoints[middle]) {
        upper = middle;
      } else {
        lower = middle + 1;
      }
    }
    return lower;
  }

  int? tabIndexAt(double flowX) {
    if (flowX < 0 || flowX >= totalWidth) return null;

    var lower = 0;
    var upper = _edges.length - 1;
    while (lower < upper) {
      final middle = (lower + upper) ~/ 2;
      if (flowX < _edges[middle + 1]) {
        upper = middle;
      } else {
        lower = middle + 1;
      }
    }
    return lower;
  }
}

/// כרטיסיה בודדת ברצועה, ניתנת לגרירה.
class _DraggableTab extends StatelessWidget {
  final OpenedTab tab;
  final Axis axis;
  final double extent;
  final double? crossExtent;
  final bool requireLongPress;
  final VoidCallback? onDragStarted;
  final VoidCallback onDragFinished;
  final Widget child;

  const _DraggableTab({
    super.key,
    required this.tab,
    required this.axis,
    required this.extent,
    required this.crossExtent,
    required this.requireLongPress,
    required this.onDragStarted,
    required this.onDragFinished,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // הכרטיסיה נשארת במקומה מעומעמת ולא נעלמת: היעלמותה הייתה משנה את חלוקת
    // המידות באמצע הגרירה ומזיזה את שאר הכרטיסיות תחת הסמן.
    final placeholder = Opacity(opacity: _kDraggingTabOpacity, child: child);
    final isVertical = axis == Axis.vertical;
    final feedback = _TabDragFeedback(
      width: isVertical ? crossExtent : extent,
      height: isVertical ? extent : null,
      child: child,
    );

    if (requireLongPress) {
      return LongPressDraggable<OpenedTab>(
        data: tab,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: feedback,
        childWhenDragging: placeholder,
        onDragStarted: onDragStarted,
        onDragEnd: (_) => onDragFinished(),
        onDraggableCanceled: (_, _) => onDragFinished(),
        child: child,
      );
    }

    return Draggable<OpenedTab>(
      data: tab,
      // חובה: ה-offset שמקבלים יעדי ההפלה הוא פינת ה-feedback, ולכן עוגן
      // ברירת המחדל מסיט את אזור ההפלה בכחצי רוחב כרטיסיה.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback,
      childWhenDragging: placeholder,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragFinished(),
      onDraggableCanceled: (_, _) => onDragFinished(),
      child: child,
    );
  }
}

/// הכרטיסיה הצפה תחת הסמן בזמן גרירה.
///
/// מוצגת ב-[Overlay] ולכן אינה יורשת את ערכת הנושא ואת שכבת ה-[Material]
/// של הרצועה — בלי העטיפה המפורשת הצבעים נופלים לברירות מחדל.
class _TabDragFeedback extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;

  const _TabDragFeedback({
    required this.width,
    this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: Directionality.of(context),
      child: Theme(
        data: theme,
        // העוגן הוא נקודת המצביע, ולכן הכרטיסיה מוזזת כדי לרחף סביבה.
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      ),
    );
  }
}

/// קו המסמן היכן הכרטיסיה הנגררת תיכנס — אנכי ברצועה אופקית ולהפך.
class _InsertIndicator extends StatelessWidget {
  final Axis axis;

  /// קצה ההתחלה של הקו, כבר ממורכז על נקודת ההכנסה ומוגבל לגבולות הרצועה.
  final double offset;

  const _InsertIndicator({required this.axis, required this.offset});

  @override
  Widget build(BuildContext context) {
    final isVertical = axis == Axis.vertical;
    return Positioned(
      top: isVertical ? offset : 4,
      bottom: isVertical ? null : 4,
      left: isVertical ? 4 : offset,
      right: isVertical ? 4 : null,
      width: isVertical ? null : _kInsertLineWidth,
      height: isVertical ? _kInsertLineWidth : null,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(_kInsertLineWidth / 2),
          ),
        ),
      ),
    );
  }
}
