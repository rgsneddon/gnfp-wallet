/// Numeric version from GitHub `gnfp` commit progression.
///
/// `versionFromCommitCount(n)` → `0.1.<n>` so more commits always sort higher.
library;

class GnfpVersion {
  const GnfpVersion(this.commitCount);

  final int commitCount;

  /// Progressive integer version: 0.1.<commitCount>
  String get numeric {
    final n = commitCount < 0 ? 0 : commitCount;
    return '0.1.$n';
  }

  int get buildNumber => commitCount < 0 ? 0 : commitCount;

  static int compare(String a, String b) {
    List<int> parts(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final pa = parts(a);
    final pb = parts(b);
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
