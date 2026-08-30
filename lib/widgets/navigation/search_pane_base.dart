import 'dart:async';
import 'package:flutter/material.dart';
import 'package:otzaria_icons/otzaria_icons.dart';
import 'package:otzaria/widgets/navigation/nav_panel_search.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';

class SearchPaneBase extends StatefulWidget {
  const SearchPaneBase({
    required this.searchController,
    required this.focusNode,
    this.progressWidget,
    this.resultCountString,
    this.resultToolbar,
    required this.resultsWidget,
    required this.isNoResults,
    this.errorMessage,
    this.onSearchTextChanged,
    required this.resetSearchCallback,
    this.hintText,
    this.onAdvancedSearch,
    this.additionalActions,
    this.collapsibleOnScroll = false,
    this.onSubmitted,
    this.onArrowDown,
    this.onArrowUp,
    super.key,
  });

  final TextEditingController searchController;
  final FocusNode focusNode;
  final Widget? progressWidget;
  final String? resultCountString;
  final Widget? resultToolbar;
  final Widget resultsWidget;
  final bool isNoResults;

  /// הודעת שגיאה אחרונה בחיפוש (כשל מנוע/FFI). כשאינה null ו-[isNoResults]
  /// אמת, מוצגת במקום "אין תוצאות" הגנרי — כדי שתקלה לא תיראה כמו חיפוש
  /// ריק לגיטימי.
  final String? errorMessage;
  final ValueChanged<String>? onSearchTextChanged;
  final VoidCallback resetSearchCallback;
  final String? hintText;
  final VoidCallback? onAdvancedSearch;
  final List<Widget>? additionalActions;
  final bool collapsibleOnScroll;
  final VoidCallback? onSubmitted;

  /// דפדוף בתוצאות בחיצים כשהפוקוס בשדה החיפוש (ראה [NavPanelSearchDelegate]).
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowUp;

  @override
  State<SearchPaneBase> createState() => _SearchPaneBaseState();
}

class _SearchPaneBaseState extends State<SearchPaneBase> {
  Timer? _debounceTimer;
  bool _isCompact = false;

  void _debounce(VoidCallback action) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      action();
      _debounceTimer = null;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!widget.collapsibleOnScroll) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final offset = notification.metrics.pixels;

      // גלילה למטה > 4dp: כווץ
      if (delta > 4 && !_isCompact) {
        setState(() => _isCompact = true);
      }
      // גלילה למעלה או חזרה לראש: פתח
      else if ((delta < -4 || offset <= 0) && _isCompact) {
        setState(() => _isCompact = false);
      }
    }

    // פוקוס בשדה — תמיד פתוח
    if (notification is UserScrollNotification && _isCompact) {
      if (widget.focusNode.hasFocus) {
        setState(() => _isCompact = false);
      }
    }

    return false;
  }

  /// פעולת החיפוש שמפורסמת לסרגל שמעל החלונית (במקום שדה מקומי).
  NavPanelSearchDelegate get _delegate => NavPanelSearchDelegate(
    controller: widget.searchController,
    focusNode: widget.focusNode,
    hintText: widget.hintText ?? '',
    onChanged: (value) =>
        _debounce(() => widget.onSearchTextChanged?.call(value)),
    onSubmitted: (_) {
      widget.onSubmitted?.call();
      widget.focusNode.requestFocus();
    },
    onClear: () {
      widget.onSearchTextChanged?.call('');
      widget.resetSearchCallback();
      widget.focusNode.requestFocus();
    },
    trailingActions: [
      if (widget.onAdvancedSearch != null)
        OtzariaSearchAction.settings(onPressed: widget.onAdvancedSearch!),
    ],
    onArrowDown: widget.onArrowDown,
    onArrowUp: widget.onArrowUp,
  );

  @override
  Widget build(BuildContext context) {
    // בתוך חלונית ניווט השדה מצויר בסרגל שמעליה, ולכן מפרסמים ולא מציירים.
    final hoisted = NavPanelSearch.isHoisted(context);
    final delegate = _delegate;
    final searchField = Padding(
      key: const ValueKey('searchField'),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Focus(
            canRequestFocus: false,
            onKeyEvent: (node, event) => delegate.handleArrowKey(event),
            child: OtzariaSearchField(
              controller: widget.searchController,
              focusNode: widget.focusNode,
              autofocus: true,
              hintText: widget.hintText ?? '',
              onChanged: (value) =>
                  _debounce(() => widget.onSearchTextChanged?.call(value)),
              onSubmitted: (_) {
                widget.onSubmitted?.call();
                widget.focusNode.requestFocus();
              },
              onClear: () {
                widget.onSearchTextChanged?.call('');
                widget.resetSearchCallback();
                widget.focusNode.requestFocus();
              },
              isCompact: _isCompact,
              onExpand: () => setState(() => _isCompact = false),
              leading: const Icon(OtzariaIcons.search_24_regular),
              trailingActions: [
                if (widget.onAdvancedSearch != null)
                  OtzariaSearchAction.settings(
                    onPressed: widget.onAdvancedSearch!,
                  ),
              ],
            ),
          ),
          if (!_isCompact &&
              widget.additionalActions != null &&
              widget.additionalActions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                right: 8.0,
                left: 8.0,
                bottom: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: widget.additionalActions!,
              ),
            ),
        ],
      ),
    );

    final resultsArea = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: widget.isNoResults
          ? Center(
              child: widget.errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        widget.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : const Text('אין תוצאות'),
            )
          : widget.resultsWidget,
    );

    final shouldShowToolbarRow =
        widget.resultToolbar != null ||
        (!_isCompact && widget.resultCountString != null);

    final pane = Column(
      children: [
        if (widget.progressWidget != null) widget.progressWidget!,
        if (!hoisted)
          AnimatedAlign(
            key: const ValueKey('searchFieldAlign'),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: _isCompact
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.center,
            child: searchField,
          ),
        if (shouldShowToolbarRow)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 4.0,
              horizontal: 16.0,
            ),
            child: Row(
              children: [
                if (!_isCompact && widget.resultCountString != null)
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        widget.resultCountString!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (widget.resultToolbar != null) widget.resultToolbar!,
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: resultsArea,
          ),
        ),
      ],
    );

    if (!hoisted) return pane;
    return NavPanelSearchPublisher(delegate: _delegate, child: pane);
  }
}
