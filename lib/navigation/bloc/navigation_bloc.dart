import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/navigation_repository.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/tabs/models/tab.dart' show OpenedTab;
import 'package:otzaria/tabs/tabs_repository.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final NavigationRepository _repository;
  StreamSubscription<OpenedTab?>? _activePaneSubscription;

  /// [activePaneStream] — זרם החלונית הפעילה מ-TabsBloc. "חיפוש" ו"עיון" הם
  /// אותו עמוד טאבים, ומעבר ביניהם (לחיצה על תוצאת חיפוש, החלפת לשונית
  /// עליונה) עובר דרך TabsBloc בלבד; בלי היישור הזה currentScreen מתאבן על
  /// הערך האחרון שנשלח ב-NavigateToScreen והסרגל מדגיש את האייקון הלא-נכון.
  NavigationBloc({
    required this._repository,
    required TabsRepository tabsRepository,
    Stream<OpenedTab?>? activePaneStream,
  }) : super(NavigationState.initial(tabsRepository.loadTabs().isNotEmpty)) {
    on<NavigateToScreen>(_onNavigateToScreen);
    on<CheckLibrary>(_onCheckLibrary);
    on<SyncScreenWithActivePane>(_onSyncScreenWithActivePane);
    _activePaneSubscription = activePaneStream?.listen(
      (pane) => add(SyncScreenWithActivePane(pane)),
    );
  }

  void _onNavigateToScreen(
    NavigateToScreen event,
    Emitter<NavigationState> emit,
  ) {
    emit(state.copyWith(currentScreen: event.screen));
  }

  void _onSyncScreenWithActivePane(
    SyncScreenWithActivePane event,
    Emitter<NavigationState> emit,
  ) {
    final current = state.currentScreen;
    // מסכים שאינם עמוד הטאבים (ספרייה/הגדרות) אינם נחטפים בגלל שינוי טאב
    // ברקע; וכשאין חלונית (נסגרו כל הטאבים) אין למה ליישר.
    if (current != Screen.reading && current != Screen.search) return;
    final pane = event.activePane;
    if (pane == null) return;
    final target = pane is SearchingTab ? Screen.search : Screen.reading;
    if (target == current) return;
    emit(state.copyWith(currentScreen: target));
  }

  void _onCheckLibrary(
    CheckLibrary event,
    Emitter<NavigationState> emit,
  ) {
    final isEmpty = _repository.checkLibraryIsEmpty();
    if (!isEmpty) {
      unawaited(AppPaths.markLibraryLoadedOnce());
    }
    emit(state.copyWith(isLibraryEmpty: isEmpty, hasCheckedLibrary: true));
  }

  Future<void> refreshLibrary() async {
    await _repository.refreshLibrary();
    add(const CheckLibrary());
  }

  @override
  Future<void> close() {
    // הביטול חייב להקדים את הסגירה — listener שעוד חי היה קורא add() על
    // bloc סגור וזורק StateError.
    _activePaneSubscription?.cancel();
    return super.close();
  }
}
