/// Public wallet pin is 0.0.2 onward. Earlier 0.1.x / 1.x pins are 0.0.1.
///
/// `versionFromCommitCount(n)` → `0.0.1` when n<=1, else `0.0.n`.
library;

class GnfpVersion {
  const GnfpVersion(this.commitCount);

  final int commitCount;

  /// Progressive 0.0.n pin. Counts 0 and 1 stay on the 0.0.1 era.
  String get numeric {
    final n = commitCount < 0 ? 0 : commitCount;
    if (n <= 1) return '0.0.1';
    return '0.0.$n';
  }

  int get buildNumber => commitCount < 0 ? 0 : commitCount;

  /// 1.x and 0.1.x are pre-reset. 0.0.2+ is the public series.
  static bool isLegacyPin(String version) {
    final p = version.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    if (p.isEmpty) return true;
    if (p[0] > 0) return true;
    if (p.length >= 2 && p[1] > 0) return true;
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
