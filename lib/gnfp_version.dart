/// Public pins use digits 0–9 only: 0.0.1 … 0.0.9, then 0.1.0.
/// Pre-reset 1.x and 0.1.10+ stay legacy (compare as 0.0.1).
///
/// `versionFromCommitCount(n)` → `0.0.1` when n<=1, else `0.{n~/10}.{n%10}`.
library;

class GnfpVersion {
  const GnfpVersion(this.commitCount);

  final int commitCount;

  /// Progressive pin. Counts 0 and 1 stay on the 0.0.1 era.
  String get numeric {
    final n = commitCount < 0 ? 0 : commitCount;
    if (n <= 1) return '0.0.1';
    return '0.${n ~/ 10}.${n % 10}';
  }

  int get buildNumber => commitCount < 0 ? 0 : commitCount;

  /// Old 1.x and pre-reset 0.1.10+ (patch ≥ 10). New 0.1.0–0.1.9 are public.
  static bool isLegacyPin(String version) {
    final p = version.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    if (p.isEmpty) return true;
    if (p[0] > 0) return true;
    final minor = p.length >= 2 ? p[1] : 0;
    final patch = p.length >= 3 ? p[2] : 0;
    if (minor > 0 && patch >= 10) return true;
    return false;
  }

  static String shipPin(String version) =>
      isLegacyPin(version) ? '0.0.1' : version;

  static int compare(String a, String b) {
    List<int> parts(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final left = (isLegacyPin(a) && isLegacyPin(b)) ? a : shipPin(a);
    final right = (isLegacyPin(a) && isLegacyPin(b)) ? b : shipPin(b);
    final pa = parts(left);
    final pb = parts(right);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final da = i < pa.length ? pa[i] : 0;
      final db = i < pb.length ? pb[i] : 0;
      if (da != db) return da.compareTo(db);
    }
    return 0;
  }
}

GnfpVersion versionFromCommitCount(int commitCount) =>
    GnfpVersion(commitCount);
