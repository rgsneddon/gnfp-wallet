import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';

void main() {
  test('default GnfpPoolClient sets connectionTimeout so hung TLS cannot look like forever Network Tip', () {
    final client = GnfpPoolClient();
    addTearDown(() => client.httpClient.close(force: true));
    expect(client.httpClient.connectionTimeout, isNotNull);
    expect(
      client.httpClient.connectionTimeout,
      GnfpPoolClient.defaultConnectionTimeout,
    );
    expect(client.httpClient.connectionTimeout!.inSeconds, greaterThanOrEqualTo(4));
  });
}
