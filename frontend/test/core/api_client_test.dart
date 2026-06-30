import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';

void main() {
  test('parseApiError preserves ProblemDetail errorCode', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/v1/pets/1/wallet/expenses'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/pets/1/wallet/expenses'),
        statusCode: 404,
        data: {
          'title': 'Not Found',
          'detail': 'Wallet expense not found.',
          'errorCode': 'WALLET_EXPENSE_NOT_FOUND',
        },
      ),
    );

    final parsed = parseApiError(error);

    expect(parsed.statusCode, 404);
    expect(parsed.title, 'Not Found');
    expect(parsed.detail, 'Wallet expense not found.');
    expect(parsed.errorCode, 'WALLET_EXPENSE_NOT_FOUND');
  });
}
