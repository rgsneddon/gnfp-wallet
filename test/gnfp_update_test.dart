import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_update.dart';

void main() {
  test('older local vs published feed offers direct installer URL', () {
    const feed = GnfpPublishedFeed(
      version: '0.1.11',
      assets: {
        'gnfp-wallet-0.1.11-windows.zip':
            'https://github.com/rgsneddon/gnfp-wallet/releases/download/v0.1.11/gnfp-wallet-0.1.11-windows.zip',
      },
    );
    final info = GnfpUpdateCheck.evaluate(
      localVersion: '0.1.10',
      feed: feed,
      platform: 'windows',
    );
    expect(info.updateAvailable, isTrue);
    expect(info.updateUrl, isNotEmpty);
    expect(info.updateUrl, contains('gnfp-wallet-0.1.11-windows.zip'));
    expect(info.updateUrl, contains('github.com/rgsneddon/gnfp-wallet/releases'));
  });

  test('newer local version does not claim an update', () {
    const feed = GnfpPublishedFeed(version: '0.1.10');
    final info = GnfpUpdateCheck.evaluate(
      localVersion: '0.1.11',
      feed: feed,
      platform: 'windows',
    );
    expect(info.updateAvailable, isFalse);
    expect(info.updateUrl, isEmpty);
  });

  test('same local version does not claim an update', () {
    const feed = GnfpPublishedFeed(version: '0.1.11');
    final info = GnfpUpdateCheck.evaluate(
      localVersion: '0.1.11',
      feed: feed,
      platform: 'windows',
    );
    expect(info.updateAvailable, isFalse);
    expect(info.updateUrl, isEmpty);
  });

  test('thrown feed does not escape check', () async {
    final checker = GnfpUpdateCheck(
      fetchJson: (_) async => throw StateError('boom'),
    );
    final info = await checker.check(localVersion: '0.1.11', platform: 'windows');
    expect(info.updateAvailable, isFalse);
    expect(info.updateUrl, isEmpty);
    expect(info.localVersion, '0.1.11');
  });

  test('check uses injected GitHub feed on the shipped checker', () async {
    final checker = GnfpUpdateCheck(
      fetchJson: (url) async {
        expect(url.toString(), contains('rgsneddon/gnfp-wallet'));
        return {
          'tag_name': 'v0.1.20',
          'html_url': 'https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.1.20',
          'assets': [
            {
              'name': 'gnfp-wallet-0.1.20-linux.zip',
              'browser_download_url':
                  'https://github.com/rgsneddon/gnfp-wallet/releases/download/v0.1.20/gnfp-wallet-0.1.20-linux.zip',
            },
          ],
        };
      },
    );
    final info = await checker.check(localVersion: '0.1.5', platform: 'linux');
    expect(info.updateAvailable, isTrue);
    expect(info.publishedVersion, '0.1.20');
    expect(info.updateUrl.endsWith('gnfp-wallet-0.1.20-linux.zip'), isTrue);
  });
}
