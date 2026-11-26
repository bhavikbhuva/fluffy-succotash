import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/category/models/category_layout_model.dart';
import 'package:customer/features/category/repositories/category_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class CategoryLayoutState {}

final class CategoryLayoutInitial extends CategoryLayoutState {}

final class CategoryLayoutLoading extends CategoryLayoutState {}

final class CategoryLayoutLoaded extends CategoryLayoutState {
  final CategoryLayoutModel categoryLayout;
  final bool isLoadingMore;
  final bool hasMore;
  CategoryLayoutLoaded(
    this.categoryLayout, {
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  CategoryLayoutLoaded copyWith({
    CategoryLayoutModel? categoryLayout,
    bool? isLoadingMore,
    bool? hasMore,
  }) => CategoryLayoutLoaded(
    categoryLayout ?? this.categoryLayout,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
  );
}

// Includes the "not deliverable" error for a location outside every zone —
// shown the same way home shows it.
final class CategoryLayoutError extends CategoryLayoutState {
  final String message;
  CategoryLayoutError(this.message);
}

class CategoryLayoutCubit extends Cubit<CategoryLayoutState> {
  final CategoryRepository _repository;

  CategoryLayoutCubit({CategoryRepository? repository})
    : _repository = repository ?? CategoryRepository(),
      super(CategoryLayoutInitial());

  int _generation = 0;
  // Generation of the sections currently on screen; differs from
  // _generation while a reload is in flight.
  int _loadedGeneration = -1;
  // Channel the current/in-flight layout was requested for — quick and
  // ecommerce in the same city can serve different categories.
  String? _channel;
  int _offset = 0;

  static const int _limit = AppConstants.homeSectionsPageLimit;

  /// Skeleton only when nothing is on screen yet (first load, after an
  /// error) or [emitLoadingState] is set. Pull-to-refresh and location/
  /// language/channel reloads keep the current sections until the new
  /// layout lands, and only the latest call's response is applied.
  Future<void> loadCategoryLayout({bool emitLoadingState = false}) async {
    final generation = ++_generation;
    final channel = SettingsHiveBox.instance.channel;
    _channel = channel;
    _offset = 0;
    try {
      if (emitLoadingState || state is! CategoryLayoutLoaded) {
        emit(CategoryLayoutLoading());
      }
      final result = await _repository.getCategoryLayout(
        channel: channel,
        offset: _offset,
        limit: _limit,
      );
      // Discard stale response: a newer load started after this one and
      // must win, regardless of which call resolves first.
      if (generation != _generation) return;
      _loadedGeneration = generation;
      emit(CategoryLayoutLoaded(result, hasMore: _advance(result)));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(CategoryLayoutError(e.message));
    } catch (_) {
      if (generation != _generation) return;
      emit(
        CategoryLayoutError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  /// Reloads when the session channel moved since the last load (switched
  /// on home while this tab sat in the background).
  void reloadIfChannelChanged() {
    if (_channel != null && _channel != SettingsHiveBox.instance.channel) {
      loadCategoryLayout();
    }
  }

  Future<void> loadMoreSections() async {
    final current = state;
    if (current is! CategoryLayoutLoaded ||
        current.isLoadingMore ||
        !current.hasMore ||
        _channel == null ||
        // Reload in flight — the sections on screen are about to be
        // replaced, appending to them would mix old and new layouts.
        _loadedGeneration != _generation) {
      return;
    }
    final generation = _generation;
    emit(current.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.getCategoryLayout(
        channel: _channel!,
        offset: _offset,
        limit: _limit,
      );
      if (generation != _generation) return;
      final layout = current.categoryLayout.data?.layout;
      layout?.sections = [
        ...?layout.sections,
        ...?result.data?.layout?.sections,
      ];
      emit(
        current.copyWith(
          categoryLayout: current.categoryLayout,
          isLoadingMore: false,
          hasMore: _advance(result),
        ),
      );
    } on ApiException catch (_) {
      if (generation != _generation) return;
      // Load-more failures stay silent — the rendered sections are kept and
      // the next scroll retries.
      emit(current.copyWith(isLoadingMore: false));
    } catch (_) {
      if (generation != _generation) return;
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  // Moves _offset past the page just loaded and says whether another page
  // exists. Paging follows the server's own rule — next offset is
  // offset + limit, more while that is below total_sections — rather than
  // counting returned sections, since emptied sections are dropped
  // server-side and a page can come back short.
  bool _advance(CategoryLayoutModel result) {
    final data = result.data;
    final count = data?.layout?.sections?.length ?? 0;
    final offset = data?.offset ?? _offset;
    final limit = data?.limit ?? _limit;
    final total = data?.totalSections;
    _offset = offset + limit;
    return total != null ? _offset < total : count >= limit;
  }
}
