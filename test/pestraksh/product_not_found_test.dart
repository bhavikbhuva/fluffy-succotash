// PestRaksh: a deleted service shows "Service not found", while a network or
// server hiccup still shows the normal error with Retry.
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/products/cubit/product_detail_cubit.dart';
import 'package:customer/features/products/models/product_detail_model.dart';
import 'package:customer/features/products/repositories/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers `getProductDetail` with whatever [answer] does.
class _FakeProductRepository extends ProductRepository {
  final Future<ProductDetailModel> Function() answer;

  _FakeProductRepository(this.answer);

  @override
  Future<ProductDetailModel> getProductDetail({required String productId}) =>
      answer();
}

/// What `ApiClient._handleResponse` throws for the live answer to an unknown
/// id or slug: HTTP 200 with `{"status":0,"message":"No item(s) found",
/// "status_code":404}`.
const _liveNotFound = ApiException(
  message: 'No item(s) found',
  statusCode: 200,
  messageStatusCode: '404',
  responseData: {
    'status': 0,
    'message': 'No item(s) found',
    'status_code': 404,
  },
);

Future<ProductDetailState> _load(
  Future<ProductDetailModel> Function() answer,
) async {
  final cubit = ProductDetailCubit(repository: _FakeProductRepository(answer));
  await cubit.loadProductDetail('999999');
  final state = cubit.state;
  await cubit.close();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the live 404 answer ends in ProductDetailNotFound', () async {
    final state = await _load(() async => throw _liveNotFound);
    expect(state, isA<ProductDetailNotFound>());
  });

  test('a success with no data also ends in ProductDetailNotFound', () async {
    final state = await _load(
      () async => ProductDetailModel(status: 1, message: 'ok'),
    );
    expect(state, isA<ProductDetailNotFound>());
  });

  test('no network still ends in ProductDetailError', () async {
    final state = await _load(
      () async => throw const ApiException(message: 'No internet connection'),
    );
    expect(state, isA<ProductDetailError>());
    expect((state as ProductDetailError).message, 'No internet connection');
  });

  test('a server error (HTTP 500) still ends in ProductDetailError', () async {
    final state = await _load(
      () async =>
          throw const ApiException(message: 'Server error', statusCode: 500),
    );
    expect(state, isA<ProductDetailError>());
  });

  test('another status 0 answer is not mistaken for not found', () async {
    final state = await _load(
      () async => throw const ApiException(
        message: 'Something went wrong',
        statusCode: 200,
        messageStatusCode: '500',
      ),
    );
    expect(state, isA<ProductDetailError>());
  });
}
