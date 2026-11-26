import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/wallet/models/transaction_model.dart';
import 'package:customer/features/wallet/repositories/wallet_repository.dart';

class TransactionCubit extends BasePaginationCubit<TransactionData> {
  final WalletRepository _repo;

  TransactionCubit({WalletRepository? repository})
    : _repo = repository ?? WalletRepository();

  String _filter = '';
  String get filter => _filter;

  /// Reload list with new filter ('' = all).
  Future<void> setFilter(String value) async {
    if (value == _filter) return;
    _filter = value;
    await fetchInitial();
  }

  @override
  PaginationFetcher<TransactionData> get fetcher =>
      (offset) => _repo.getUserTransactions(
        offset: offset,
        limit: AppConfig.pageLimit,
        filter: _filter,
      );
}
