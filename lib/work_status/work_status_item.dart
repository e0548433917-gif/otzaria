import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum WorkStatusKind { running, failed, cancelled }

/// לחצן פעולה בשורת הפעולות של פריט חיווי; [emphasized] מציג אותו כלחוץ
/// (tonal) — למצב פעיל של פעולת toggle.
class WorkStatusAction {
  final String label;
  final IconData icon;
  final String? tooltip;
  final bool emphasized;
  final VoidCallback onPressed;

  const WorkStatusAction({
    required this.label,
    required this.icon,
    this.tooltip,
    this.emphasized = false,
    required this.onPressed,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkStatusAction &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          icon == other.icon &&
          tooltip == other.tooltip &&
          emphasized == other.emphasized &&
          onPressed == other.onPressed;

  @override
  int get hashCode => Object.hash(label, icon, tooltip, emphasized, onPressed);
}

class WorkStatusItem {
  final String id;
  final String title;
  final String message;
  final String? detail;
  final double? progress;
  final WorkStatusKind kind;

  /// פעולה בלחיצה על החיווי. פריט ללא ערך אינו לחיץ.
  final VoidCallback? onTap;

  /// לחצני פעולה המוצגים מתחת לפרטי הפריט (רק בפריט הראשי).
  final List<WorkStatusAction> actions;

  /// משך שאחריו הפריט יורד מעצמו; `null` = נשאר עד סגירה ידנית.
  final Duration? autoDismissAfter;

  const WorkStatusItem({
    required this.id,
    required this.title,
    required this.message,
    this.detail,
    this.progress,
    this.kind = WorkStatusKind.running,
    this.onTap,
    this.actions = const [],
    this.autoDismissAfter,
  });

  WorkStatusItem copyWith({
    String? id,
    String? title,
    String? message,
    String? detail,
    Object? progress = _sentinel,
    WorkStatusKind? kind,
    Object? onTap = _sentinel,
    List<WorkStatusAction>? actions,
    Object? autoDismissAfter = _sentinel,
  }) {
    return WorkStatusItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      detail: detail ?? this.detail,
      progress: progress == _sentinel ? this.progress : progress as double?,
      kind: kind ?? this.kind,
      onTap: onTap == _sentinel ? this.onTap : onTap as VoidCallback?,
      actions: actions ?? this.actions,
      autoDismissAfter: autoDismissAfter == _sentinel
          ? this.autoDismissAfter
          : autoDismissAfter as Duration?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkStatusItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          message == other.message &&
          detail == other.detail &&
          progress == other.progress &&
          kind == other.kind &&
          onTap == other.onTap &&
          listEquals(actions, other.actions) &&
          autoDismissAfter == other.autoDismissAfter;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      message.hashCode ^
      detail.hashCode ^
      progress.hashCode ^
      kind.hashCode ^
      onTap.hashCode ^
      Object.hashAll(actions) ^
      autoDismissAfter.hashCode;
}

const Object _sentinel = Object();
