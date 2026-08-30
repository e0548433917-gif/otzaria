import 'package:equatable/equatable.dart';
import 'package:otzaria/indexing/models/indexing_run_result.dart';

sealed class IndexingState extends Equatable {
  final int? booksProcessed;
  final int? totalBooks;
  final bool isCreatingIndex;

  const IndexingState({
    this.booksProcessed,
    this.totalBooks,
    this.isCreatingIndex = false,
  });

  @override
  List<Object?> get props => [booksProcessed, totalBooks, isCreatingIndex];
}

class IndexingInitial extends IndexingState {}

class IndexingInProgress extends IndexingState {
  const IndexingInProgress({
    super.booksProcessed,
    super.totalBooks,
    super.isCreatingIndex,
    this.isPaused = false,
    this.isEconomy = false,
  });

  /// האינדוקס מושהה — הלולאה ממתינה לפני הספר הבא.
  final bool isPaused;

  /// מצב חסכוני פעיל — המנוע רץ עם תקציב writer מוקטן.
  final bool isEconomy;

  @override
  List<Object?> get props => [...super.props, isPaused, isEconomy];
}

class IndexingComplete extends IndexingState {
  const IndexingComplete({this.failures = const []});

  final List<IndexingFailure> failures;

  bool get isClean => failures.isEmpty;
  int get failureCount => failures.length;

  @override
  List<Object?> get props => [failures];
}

class IndexingStopped extends IndexingState {}

class IndexingError extends IndexingState {
  final String error;

  const IndexingError(this.error, {super.booksProcessed, super.totalBooks});

  @override
  List<Object?> get props => [error, booksProcessed, totalBooks];
}
