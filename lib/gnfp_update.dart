/// Compare local wallet pin to a published feed and pick a direct installer URL.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gnfp_version.dart';

class GnfpPublishedFeed {
  const GnfpPublishedFeed({
    required this.version,
    this.assets = const {},
    this.releasePageUrl = '',
  });

  final String version;
  final Map<String, String> assets;
  final String releasePageUrl;

  factory GnfpPublishedFeed.fromGithubRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] ?? json['name'] ?? '').toString().trim();
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    final assets = <String, String>{};
    final list = json['assets'];
    if (list is List) {
      for (final raw in list) {
        if (raw is! Map) continue;
        final name = raw['name']?.toString() ?? '';
        final url = raw['browser_download_url']?.toString() ?? '';
        if (name.isEmpty || url.isEmpty) continue;
        assets[name] = url;
      }
    }
    final html = json['html_url']?.toString() ?? '';
    return GnfpPublishedFeed(
      version: version,
      assets: assets,
      releasePageUrl: html.isNotEmpty
          ? html
          : 'https://github.com/rgsneddon/gnfp-wallet/releases/tag/v$version',
    );
  }

  factory GnfpPublishedFeed.fromVersionDoc(Map<String, dynamic> json) {
    final version = (json['version'] ?? '').toString().trim();
    return GnfpPublishedFeed(
      version: version,
      releasePageUrl:
          'https://github.com/rgsneddon/gnfp-wallet/releases/tag/v$version',
    );
  }
}

class GnfpUpdateInfo {
  const GnfpUpdateInfo({
    required this.localVersion,
    required this.publishedVersion,
    required this.updateAvailable,
    required this.updateUrl,
  });

  final String localVersion;
  final String publishedVersion;
  final bool updateAvailable;
  final String updateUrl;
}

/// Pure compare + installer URL. Fetch is injected so tests drive this class.
class GnfpUpdateCheck {
  const GnfpUpdateCheck({this.fetchJson});

  final Future<Map<String, dynamic>?> Function(Uri url)? fetchJson;

  static const githubLatestApi =
      'https://api.github.com/repos/rgsneddon/gnfp-wallet/releases/latest';
  static const versionDocUrl =
      'https://raw.githubusercontent.com/rgsneddon/gnfp-wallet/master/version.json';
  static const releasesDownloadBase =
      'https://github.com/rgsneddon/gnfp-wallet/releases/download';

  static bool updateAvailable(String local, String remote) {
    if (local.isEmpty || remote.isEmpty) return false;
    return GnfpVersion.compare(local, remote) < 0;
  }

  static String platformKey({String? override}) {
    if (override != null && override.isNotEmpty) return override;
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'windows';
  }

  static String installerUrl(String version, String platform) {
    return '$releasesDownloadBase/v$version/gnfp-wallet-$version-$platform.zip';
  }

  static String pickUpdateUrl(
    GnfpPublishedFeed feed, {
    required String platform,
  }) {
    final zip = 'gnfp-wallet-${feed.version}-$platform.zip';
    final hit = feed.assets[zip];
    if (hit != null && hit.isNotEmpty) return hit;
    if (feed.releasePageUrl.isNotEmpty) return feed.releasePageUrl;
    return installerUrl(feed.version, platform);
  }

  static GnfpUpdateInfo evaluate({
    required String localVersion,
    required GnfpPublishedFeed feed,
    required String platform,
  }) {
    final newer = updateAvailable(localVersion, feed.version);
    return GnfpUpdateInfo(
      localVersion: localVersion,
      publishedVersion: feed.version,
      updateAvailable: newer,
      updateUrl: newer ? pickUpdateUrl(feed, platform: platform) : '',
    );
  }

  Future<GnfpUpdateInfo> check({
    required String localVersion,
    String? platform,
    GnfpPublishedFeed? feed,
  }) async {
    final plat = platformKey(override: platform);
    final resolved = feed ?? await _loadFeed();
    if (resolved == null || resolved.version.isEmpty) {
      return GnfpUpdateInfo(
        localVersion: localVersion,
        publishedVersion: localVersion,
        updateAvailable: false,
        updateUrl: '',
      );
    }
    return evaluate(
      localVersion: localVersion,
      feed: resolved,
      platform: plat,
    );
  }

  Future<GnfpPublishedFeed?> _loadFeed() async {
    try {
      final fetch = fetchJson ?? _defaultFetch;
      final gh = await fetch(Uri.parse(githubLatestApi));
      if (gh != null && (gh['tag_name'] != null || gh['name'] != null)) {
        return GnfpPublishedFeed.fromGithubRelease(gh);
      }
      final doc = await fetch(Uri.parse(versionDocUrl));
      if (doc != null && doc['version'] != null) {
        return GnfpPublishedFeed.fromVersionDoc(doc);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _defaultFetch(Uri url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      try {
        final req = await client.getUrl(url);
        req.headers.set(HttpHeaders.userAgentHeader, 'gnfp-wallet-update');
        final res = await req.close().timeout(const Duration(seconds: 6));
        if (res.statusCode < 200 || res.statusCode >= 300) return null;
        final body = await res.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        return decoded is Map<String, dynamic> ? decoded : null;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }
}
