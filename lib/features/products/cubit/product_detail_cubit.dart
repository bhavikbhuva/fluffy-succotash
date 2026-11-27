import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/products/models/product_detail_model.dart';
import 'package:customer/features/products/repositories/product_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ProductDetailState {}

final class ProductDetailInitial extends ProductDetailState {}

final class ProductDetailLoading extends ProductDetailState {}

final class ProductDetailLoaded extends ProductDetailState {
  final ProductDetailDataModel product;
  final int selectedVariantIndex;
  final Map<int, int> selectedAxisValues;

  ProductDetailLoaded(
    this.product, {
    this.selectedVariantIndex = 0,
    Map<int, int>? selectedAxisValues,
  }) : selectedAxisValues = selectedAxisValues ?? _defaultAxisValues(product);

  static Map<int, int> _defaultAxisValues(ProductDetailDataModel product) {
    final axes = product.variantAxes ?? [];
    final variants = product.variants ?? [];
    if (axes.isEmpty || variants.isEmpty) return {};
    return axisValuesForVariant(variants.first);
  }

  static Map<int, int> axisValuesForVariant(Variants variant) {
    final result = <int, int>{};
    for (final attr in variant.attributes ?? []) {
      if (attr.attributeId != null && attr.attributeValueId != null) {
        result[attr.attributeId!] = attr.attributeValueId!;
      }
    }
    return result;
  }

  ProductDetailLoaded copyWith({
    ProductDetailDataModel? product,
    int? selectedVariantIndex,
    Map<int, int>? selectedAxisValues,
  }) {
    return ProductDetailLoaded(
      product ?? this.product,
      selectedVariantIndex: selectedVariantIndex ?? this.selectedVariantIndex,
      selectedAxisValues: selectedAxisValues ?? this.selectedAxisValues,
    );
  }
}

final class ProductDetailError extends ProductDetailState {
  final String message;
  ProductDetailError(this.message);
}

// PestRaksh: the service was deleted (an old favourite or link). Kept apart
// from ProductDetailError so the screen shows "Service not found" with a way
// to other services instead of a Retry that can never help.
final class ProductDetailNotFound extends ProductDetailState {}

class ProductDetailCubit extends Cubit<ProductDetailState>
    with ApiErrorGuard<ProductDetailState> {
  final ProductRepository _repository;

  ProductDetailCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super(ProductDetailInitial());

  Future<void> loadProductDetail(
    String productId, {
    int? targetVariantId,
  }) async {
    emit(ProductDetailLoading());
    await guard(() async {
      final ProductDetailModel result;
      try {
        result = await _repository.getProductDetail(productId: productId);
      } on ApiException catch (e) {
        // PestRaksh: an unknown id or slug comes back as HTTP 200 with
        // `status: 0, status_code: 404`, which the client turns into
        // messageStatusCode '404'. Network and server errors never carry it,
        // so they still reach ProductDetailError and its Retry.
        if (e.messageStatusCode == '404') {
          emit(ProductDetailNotFound());
          return;
        }
        rethrow;
      }
      // PestRaksh: a success with no service in it means the same thing.
      if (result.data == null) {
        emit(ProductDetailNotFound());
        return;
      }
      final product = result.data!;
      final variants = product.variants ?? [];
      final targetIndex = targetVariantId == null
          ? -1
          : variants.indexWhere((v) => v.id == targetVariantId);
      if (targetIndex != -1) {
        emit(
          ProductDetailLoaded(
            product,
            selectedVariantIndex: targetIndex,
            selectedAxisValues: ProductDetailLoaded.axisValuesForVariant(
              variants[targetIndex],
            ),
          ),
        );
      } else {
        emit(ProductDetailLoaded(product));
      }
    }, onError: (msg) => emit(ProductDetailError(msg)));
  }

  void selectVariant(int index) {
    final s = state;
    if (s is ProductDetailLoaded) {
      emit(s.copyWith(selectedVariantIndex: index));
    }
  }

  void selectAxisValue(int attributeId, int attributeValueId) {
    final s = state;
    if (s is! ProductDetailLoaded) return;

    final updated = Map<int, int>.from(s.selectedAxisValues)
      ..[attributeId] = attributeValueId;

    final variants = s.product.variants ?? [];
    int matchIndex = s.selectedVariantIndex;
    for (int i = 0; i < variants.length; i++) {
      final attrs = variants[i].attributes ?? [];
      final matches = updated.entries.every(
        (e) => attrs.any(
          (a) => a.attributeId == e.key && a.attributeValueId == e.value,
        ),
      );
      if (matches) {
        matchIndex = i;
        break;
      }
    }

    emit(
      s.copyWith(selectedVariantIndex: matchIndex, selectedAxisValues: updated),
    );
  }
}
