import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_selection_action.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/models/plugin_context_menu_item.dart';
import 'package:otzaria/plugins/models/plugin_when_condition.dart';
import 'package:otzaria/plugins/plugin_constants.dart';
import 'package:otzaria/plugins/services/plugin_condition_evaluator.dart';

class ContextMenuRegistry extends ChangeNotifier {
  static const int maxTopLevelItemsPerPlugin = 2;

  static final ContextMenuRegistry instance = ContextMenuRegistry._();
  ContextMenuRegistry._() {
    _attachEvaluator(PluginConditionEvaluator.instance);
  }

  @visibleForTesting
  ContextMenuRegistry.forTesting({PluginConditionEvaluator? evaluator}) {
    if (evaluator != null) _attachEvaluator(evaluator);
  }

  /// מופע מנותק לפרסינג-יבש בוולידציה (אריזה/התקנה) — לא נוגע ב-UI.
  ContextMenuRegistry.detached();

  final Map<PluginInstanceKey, List<PluginContextMenuItem>> _items = {};
  PluginConditionEvaluator? _evaluator;

  void _attachEvaluator(PluginConditionEvaluator evaluator) {
    _evaluator = evaluator;
    evaluator.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _evaluator?.removeListener(notifyListeners);
    super.dispose();
  }

  PluginInstanceKey _key(String pluginId, String instanceId) =>
      (pluginId: pluginId, instanceId: instanceId);

  /// הרשימה של [instanceId] אם היא מכילה את [itemId]; אחרת הרשימה ברמת
  /// התוסף — כך JS של מופע יכול לעדכן/להסיר פריט שהוצהר במניפסט.
  List<PluginContextMenuItem>? _listContaining(
    String pluginId,
    String instanceId,
    String itemId,
  ) {
    final own = _items[_key(pluginId, instanceId)];
    if (own != null && own.any((item) => item.id == itemId)) return own;
    if (instanceId == PluginInstanceIds.pluginLevel) return null;
    final shared = _items[_key(pluginId, PluginInstanceIds.pluginLevel)];
    if (shared != null && shared.any((item) => item.id == itemId)) {
      return shared;
    }
    return null;
  }

  void register(
    String pluginId,
    PluginContextMenuItem item, {
    String instanceId = PluginInstanceIds.pluginLevel,
  }) {
    final list = _items.putIfAbsent(_key(pluginId, instanceId), () => []);
    final index = list.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      list[index] = item;
    } else {
      if (list.length >= maxTopLevelItemsPerPlugin) {
        throw const PluginContextMenuException(
          'error.invalid_params',
          'a plugin can register at most 2 top-level context menu items',
        );
      }
      list.add(item);
    }
    notifyListeners();
  }

  PluginContextMenuItem registerPayload(
    String pluginId,
    Map<String, dynamic> payload, {
    String instanceId = PluginInstanceIds.pluginLevel,
  }) {
    final item = _parseItem(payload, depth: 0);
    register(pluginId, item, instanceId: instanceId);
    return item;
  }

  PluginContextMenuItem update(
    String pluginId,
    String itemId,
    Map<String, dynamic> patch, {
    String instanceId = PluginInstanceIds.pluginLevel,
  }) {
    final list = _listContaining(pluginId, instanceId, itemId);
    final index = list?.indexWhere((item) => item.id == itemId) ?? -1;
    if (list == null || index < 0) {
      throw const PluginContextMenuException(
        'error.not_found',
        'context menu item was not found',
      );
    }
    // toJson פולט תמיד title, ולכן patch עם label בלבד היה נבלע בשקט.
    final merged = {
      ...list[index].toJson(),
      ...patch,
      if (patch.containsKey('label') && !patch.containsKey('title'))
        'title': patch['label'],
      'id': itemId,
    };
    final updated = _parseItem(merged, depth: 0);
    list[index] = updated;
    notifyListeners();
    return updated;
  }

  void remove(
    String pluginId,
    String itemId, {
    String instanceId = PluginInstanceIds.pluginLevel,
  }) {
    final list = _listContaining(pluginId, instanceId, itemId);
    if (list == null) return;
    list.removeWhere((item) => item.id == itemId);
    _items.removeWhere((_, items) => items.isEmpty);
    notifyListeners();
  }

  /// ניקוי מלא ברמת התוסף — כל המופעים והרישומים הדקלרטיביים.
  void removeAll(String pluginId) {
    final before = _items.length;
    _items.removeWhere((key, _) => key.pluginId == pluginId);
    if (_items.length != before) notifyListeners();
  }

  /// מסיר רק את הרישומים של המופע [key] (סגירת טאב אחד של התוסף).
  void removeInstance(PluginInstanceKey key) {
    if (_items.remove(key) != null) notifyListeners();
  }

  /// הפריטים המוצגים בפועל — פריט שתנאי ה-`when` שלו אינו מתקיים מסונן החוצה
  /// (ונשאר רשום, כך שהוא חוזר כשהתנאי מתקיים).
  ///
  /// תצוגה מאוחדת: פריט אחד לכל (pluginId, itemId) גם כשכמה מופעים רשמו
  /// אותו; רישום של מופע חי גובר על העותק הדקלרטיבי, המיקום לפי הראשון.
  List<(String pluginId, PluginContextMenuItem item)> getAll() {
    final evaluator = _evaluator;
    final deduped = <(String, String), (String, PluginContextMenuItem)>{};
    for (final entry in _items.entries) {
      final pluginId = entry.key.pluginId;
      for (final item in entry.value) {
        if (!(evaluator?.isVisible(pluginId, item.when) ?? true)) continue;
        final dedupeKey = (pluginId, item.id);
        if (!deduped.containsKey(dedupeKey) ||
            entry.key.instanceId != PluginInstanceIds.pluginLevel) {
          deduped[dedupeKey] = (pluginId, item);
        }
      }
    }
    return List.unmodifiable(deduped.values);
  }

  /// מזהי המופעים שרשמו את [itemId] (כולל בתוך תתי-פריטים), בסדר הרישום —
  /// הקלט לניתוב הלחיצה למופע הנכון.
  List<String> instanceIdsForItem(String pluginId, String itemId) => [
    for (final entry in _items.entries)
      if (entry.key.pluginId == pluginId &&
          entry.value.any((item) => _treeContains(item, itemId)))
        entry.key.instanceId,
  ];

  bool _treeContains(PluginContextMenuItem item, String itemId) =>
      item.id == itemId ||
      item.children.any((child) => _treeContains(child, itemId));

  /// מחזיר פריט לפי [itemId], כולל פריטי משנה בתוך תת-תפריט.
  PluginContextMenuItem? findItem(String pluginId, String itemId) {
    for (final entry in _items.entries) {
      if (entry.key.pluginId != pluginId) continue;
      for (final item in entry.value) {
        final found = _findInTree(item, itemId);
        if (found != null) return found;
      }
    }
    return null;
  }

  bool isItemVisible(String pluginId, String itemId) {
    for (final entry in _items.entries) {
      if (entry.key.pluginId != pluginId) continue;
      for (final item in entry.value) {
        if (_isVisibleInTree(pluginId, item, itemId)) return true;
      }
    }
    return false;
  }

  PluginContextMenuItem? _findInTree(
    PluginContextMenuItem item,
    String itemId,
  ) {
    if (item.id == itemId) return item;
    for (final child in item.children) {
      final found = _findInTree(child, itemId);
      if (found != null) return found;
    }
    return null;
  }

  bool _isVisibleInTree(
    String pluginId,
    PluginContextMenuItem item,
    String itemId,
  ) {
    if (!(_evaluator?.isVisible(pluginId, item.when) ?? true)) return false;
    if (item.id == itemId) return true;
    return item.children.any(
      (child) => _isVisibleInTree(pluginId, child, itemId),
    );
  }

  PluginContextMenuItem _parseItem(
    Map<String, dynamic> json, {
    required int depth,
    List<String>? inheritedContexts,
  }) {
    if (depth > 2) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'context menu nesting is too deep',
      );
    }
    // אין הגבלת תווים על id — תוספי legacy נרשמו עם ids חופשיים.
    final id = _safeText(json['id'], field: 'id', maxLength: 128);
    final type = json['type'] as String? ?? 'item';
    const types = {'item', 'submenu', 'color-row', 'separator'};
    if (!types.contains(type)) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'unsupported context menu item type',
      );
    }
    final titleValue = json['title'] ?? json['label'];
    final title = type == 'separator'
        ? null
        : _safeText(titleValue, field: 'title', maxLength: 100);
    final contextsValue = json['contexts'];
    if (contextsValue != null &&
        (contextsValue is! List ||
            contextsValue.any((value) => value is! String))) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'contexts must be an array of strings',
      );
    }
    // ברירת מחדל: שני ההקשרים — פריטי legacy (בלי contexts) הופיעו מאז ומעולם
    // גם בתפריט של צורת הדף.
    final contexts = contextsValue == null
        ? inheritedContexts ??
              const ['reader-selection', 'reader-page-shape-selection']
        : List<String>.from(contextsValue as List);
    const supportedContexts = {
      'reader-selection',
      'reader-page-shape-selection',
      'reader-highlight',
    };
    if (contexts.isEmpty ||
        contexts.toSet().length != contexts.length ||
        (contextsValue != null &&
            inheritedContexts != null &&
            contexts.any((context) => !inheritedContexts.contains(context))) ||
        contexts.any((context) => !supportedContexts.contains(context))) {
      throw const PluginContextMenuException(
        'error.unsupported_context',
        'contexts must be unique, supported, and within the parent contexts',
      );
    }

    final children = <PluginContextMenuItem>[];
    final childrenValue = json['children'];
    if (childrenValue != null) {
      if (childrenValue is! List || childrenValue.length > 30) {
        throw const PluginContextMenuException(
          'error.invalid_params',
          'children must contain at most 30 items',
        );
      }
      for (final child in childrenValue) {
        if (child is! Map) {
          throw const PluginContextMenuException(
            'error.invalid_params',
            'child must be an object',
          );
        }
        children.add(
          _parseItem(
            Map<String, dynamic>.from(child),
            depth: depth + 1,
            inheritedContexts: contexts,
          ),
        );
      }
    }

    final colors = <PluginContextMenuColor>[];
    final colorsValue = json['colors'];
    if (colorsValue != null) {
      if (colorsValue is! List ||
          colorsValue.isEmpty ||
          colorsValue.length > 12) {
        throw const PluginContextMenuException(
          'error.invalid_params',
          'colors must contain 1-12 values',
        );
      }
      for (final value in colorsValue) {
        if (value is! Map) {
          throw const PluginContextMenuException(
            'error.invalid_params',
            'color must be an object',
          );
        }
        final colorJson = Map<String, dynamic>.from(value);
        final color = _safeText(
          colorJson['color'],
          field: 'color',
          maxLength: 9,
        );
        if (!RegExp(r'^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(color)) {
          throw const PluginContextMenuException(
            'error.invalid_params',
            'colors must use #RRGGBB or #RRGGBBAA',
          );
        }
        colors.add(
          PluginContextMenuColor(
            id: _safeText(colorJson['id'], field: 'color.id', maxLength: 64),
            color: color,
            label: _safeText(
              colorJson['label'],
              field: 'color.label',
              maxLength: 64,
            ),
            icon: _optionalSafeText(colorJson['icon'], maxLength: 100),
            selected: colorJson['selected'] == true,
          ),
        );
      }
    }
    if (type == 'submenu' && children.isEmpty) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'submenu requires children',
      );
    }
    if (type == 'color-row' && colors.isEmpty) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'color-row requires colors',
      );
    }

    return PluginContextMenuItem(
      id: id,
      type: type,
      title: title,
      icon: _optionalSafeText(json['icon'], maxLength: 100),
      contexts: contexts,
      onClickEvent: _optionalEventName(json['onClickEvent']),
      onColorClickEvent: _optionalEventName(json['onColorClickEvent']),
      children: children,
      colors: colors,
      openPlugin: json['openPlugin'] == true,
      param: json['param'],
      showWhenContainsAny: _parseShowWhen(json['showWhen']),
      when: _parseWhen(json['when'], depth: depth),
      action: _parseAction(json),
    );
  }

  /// פעולת host דקלרטיבית על הפריט — ולידציה מבנית בלבד; הצהרת ההרשאה
  /// נבדקת בוולידטור ההתקנה ושוב בזמן הלחיצה.
  Map<String, dynamic>? _parseAction(Map<String, dynamic> json) {
    final value = json['action'];
    if (value == null) return null;
    if (json['type'] != null && json['type'] != 'item') {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'action is only allowed on items',
      );
    }
    if (json['onClickEvent'] != null || json['openPlugin'] == true) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'action cannot be combined with onClickEvent or openPlugin',
      );
    }
    if (value is! Map) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'action must be an object',
      );
    }
    final action = Map<String, dynamic>.from(value);
    try {
      DeclarativeSelectionAction.validateTemplate(action);
    } on DeclarativeProgramException catch (error) {
      throw PluginContextMenuException('error.invalid_params', '$error');
    }
    return action;
  }

  PluginWhenCondition? _parseWhen(Object? value, {required int depth}) {
    if (value == null) return null;
    if (depth > 0) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'when is only allowed on top-level items',
      );
    }
    try {
      return PluginWhenCondition.fromJson(value);
    } on PluginWhenConditionException catch (error) {
      throw PluginContextMenuException('error.invalid_params', '$error');
    }
  }

  /// `showWhen: {selectionContainsAny: [...]}` — עד 50 מילים, כל אחת עד 100
  /// תווים. בכוונה רשימת מילים ולא regex: ביטוי של תוסף היה רץ על כל סימון
  /// ופותח פתח ל-ReDoS.
  List<String> _parseShowWhen(Object? value) {
    if (value == null) return const [];
    if (value is! Map) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'showWhen must be an object',
      );
    }
    final words = value['selectionContainsAny'];
    if (words == null) return const [];
    if (words is! List || words.isEmpty || words.length > 50) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'showWhen.selectionContainsAny must contain 1-50 strings',
      );
    }
    return [
      for (final word in words)
        _safeText(word, field: 'showWhen.selectionContainsAny', maxLength: 100),
    ];
  }

  String _safeText(
    Object? value, {
    required String field,
    required int maxLength,
  }) {
    final text = _optionalSafeText(value, maxLength: maxLength);
    if (text == null || text.isEmpty) {
      throw PluginContextMenuException(
        'error.invalid_params',
        '$field is required',
      );
    }
    return text;
  }

  String? _optionalSafeText(Object? value, {required int maxLength}) {
    if (value == null) return null;
    if (value is! String ||
        value.length > maxLength ||
        RegExp(r'[\u0000-\u001F\u007F]').hasMatch(value)) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'text field has an invalid type or content',
      );
    }
    return value;
  }

  String? _optionalEventName(Object? value) {
    final event = _optionalSafeText(value, maxLength: 128);
    if (event != null && !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(event)) {
      throw const PluginContextMenuException(
        'error.invalid_params',
        'event name contains unsupported characters',
      );
    }
    return event;
  }
}
