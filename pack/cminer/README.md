# Bundled gnfp-cminer 1.1.0

Desktop Mine start (`MINE GNFP`) runs this binary. Phones keep the Dart hasher.

| Path | File |
|------|------|
| `macos/gnfp-cminer` | Darwin arm64 + `libssl.3.dylib` / `libcrypto.3.dylib` (`@executable_path`) |
| `linux/gnfp-cminer` | Linux x86_64 ELF (`libssl.so.3` on the host) |
| `windows/gnfp-cminer.exe` | Windows PE (static OpenSSL) |

Copied into the app next to `gnfp_wallet` / `gnfp_wallet.exe`. Do not rebuild public miner tag `v1.1.0`.
