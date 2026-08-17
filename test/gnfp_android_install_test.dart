import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release AndroidManifest grants INTERNET so the packaged APK can talk to the book', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest.contains('android.permission.INTERNET'),
      isTrue,
      reason: 'INTERNET lives only in debug/profile by default; release APKs then cannot mine or sync',
    );
    expect(manifest.contains('android.permission.ACCESS_NETWORK_STATE'), isTrue);
    expect(manifest.contains('android:networkSecurityConfig'), isTrue);
  });

  test('release Gradle can sign with a real keystore, not only the Android Debug cert', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle.contains('create("release")'), isTrue);
    expect(gradle.contains('enableV1Signing = true'), isTrue);
    expect(gradle.contains('enableV2Signing = true'), isTrue);
    expect(gradle.contains('enableV3Signing = true'), isTrue);
    expect(gradle.contains('key.properties'), isTrue);
    expect(gradle.contains('signingConfigs.getByName("release")'), isTrue);
    expect(
      gradle.contains('signingConfig = signingConfigs.getByName("debug")'),
      isFalse,
      reason: 'unconditional debug signing is what made the 0.0.8 GitHub APK uninstallable',
    );
  });
}
